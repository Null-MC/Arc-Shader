#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    void PbrLighting(out vec4 colorMapOut, out vec4 normalMapOut, out vec4 specularMapOut, out vec4 lightingMapOut) {
        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        vec4 colorMap, normalMap, specularMap;

        //normalMap.xyz = textureGrad(normals, texcoord, dFdXY[0], dFdXY[1]).xyz;
        normalMap.xyz = texture(normals, texcoord).xyz;
        bool isMissingNormal = all(lessThan(normalMap.xy, vec2(EPSILON)));
        bool isMissingTangent = any(isnan(viewTangent));

        vec2 atlasCoord = texcoord;
        float viewDist = length(viewPos);

        //if (normalMap.z > 0.0 || normalMap.z < 1.0 || isnan(normalMap.z) || isinf(normalMap.z))
        //    normalMap.xyz = vec3(0.5, 0.5, 1.0);

        #if defined PARALLAX_ENABLED && !defined RENDER_TEXTURED
            bool skipParallax = isMissingTangent || isMissingNormal;

            #ifdef RENDER_ENTITIES
                if (entityId == ENTITY_ITEM_FRAME || entityId == ENTITY_PHYSICSMOD_SNOW) skipParallax = true;
            #else
                if (materialId == MATERIAL_LAVA) skipParallax = true;
            #endif

            float texDepth = 1.0;
            vec3 traceCoordDepth = vec3(1.0);
            vec3 tanViewDir = normalize(tanViewPos);

            if (!skipParallax && viewDist < PARALLAX_DISTANCE) {
                atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);

                #ifndef MATERIAL_SMOOTH_NORMALS
                    normalMap.xyz = textureGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).xyz;
                #endif

                #ifdef PARALLAX_DEPTH_WRITE
                    float pomDist = (1.0 - traceCoordDepth.z) / max(-tanViewDir.z, 0.00001);

                    if (pomDist > 0.0) {
                        //float depth = linearizePerspectiveDepth(gl_FragCoord.z, gbufferProjection);
                        //gl_FragDepth = delinearizePerspectiveDepth(depth + pomDist * (0.25 * PARALLAX_DEPTH), gbufferProjection);
                        float depth = -viewPos.z + pomDist * PARALLAX_DEPTH;
                        gl_FragDepth = 0.5 * (-gbufferProjection[2].z*depth + gbufferProjection[3].z) / depth + 0.5;

                        #ifdef RENDER_HAND
                            gl_FragDepth *= MC_HAND_DEPTH;
                        #endif
                    }
                    else {
                        gl_FragDepth = gl_FragCoord.z;
                    }
                #endif
            }
            #ifdef PARALLAX_DEPTH_WRITE
                else {
                    gl_FragDepth = gl_FragCoord.z;
                }
            #endif
        #endif

        //if (all(lessThan(normalMap.xy, vec2(1.0/255.0))))
        //    normalMap.xyz = vec3(0.5, 0.5, 1.0);
        
        #ifdef AF_ENABLED
            colorMap = textureAnisotropic(gtexture, atlasCoord, dFdXY);
        #else
            colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]);
        #endif

        #ifdef RENDER_TEXTURED
            colorMap *= glcolor;
        #else
            colorMap.rgb *= glcolor.rgb;
        #endif

        //colorMap.a *= 0.5;

        #ifdef RENDER_ENTITIES
            if (colorMap.a < 10.0/255.0 && entityId != ENTITY_BOAT) {
                discard;
                return;
            }
        #elif defined RENDER_TEXTURED
            float threshold = InterleavedGradientNoise(gl_FragCoord.xy);
            if (colorMap.a <= threshold) {
                discard;
                return;
            }
        #else
            if (colorMap.a < 10.0/255.0) {
                discard;
                return;
            }
        #endif

        #ifdef RENDER_ENTITIES
            colorMap.rgb = mix(colorMap.rgb, entityColor.rgb, entityColor.a);

            // TODO: fix lightning?
        #endif

        #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
            specularMap = textureGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);
        #else
            specularMap = vec4(0.0);
        #endif

        float parallaxShadow = 1.0;
        vec2 lm = lmcoord;

        #if defined PARALLAX_ENABLED && defined MATERIAL_SMOOTH_NORMALS && MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT && !defined RENDER_TEXTURED && !defined RENDER_ENTITIES
            if (!isMissingNormal && !isMissingTangent) {
                ////normalMap.rgb = TexelFetchLinearRGB(normals, atlasCoord * atlasSize);
                //normalMap.rgb = TextureGradLinearRGB(normals, atlasCoord, atlasSize, dFdXY);

                vec2 uv[4];
                vec2 f = GetLinearCoords(atlasCoord, atlasSize, uv);

                uv[0] = GetAtlasCoord(GetLocalCoord(uv[0]));
                uv[1] = GetAtlasCoord(GetLocalCoord(uv[1]));
                uv[2] = GetAtlasCoord(GetLocalCoord(uv[2]));
                uv[3] = GetAtlasCoord(GetLocalCoord(uv[3]));

                ivec2 iuv[4];
                iuv[0] = ivec2(uv[0] * atlasSize);
                iuv[1] = ivec2(uv[1] * atlasSize);
                iuv[2] = ivec2(uv[2] * atlasSize);
                iuv[3] = ivec2(uv[3] * atlasSize);

                //normalMap.rgb = TextureGradLinearRGB(normals, uv, dFdXY, f);
                normalMap.xyz = TexelFetchLinearRGB(normals, iuv, 0, f);
            }
        #endif

        vec3 worldPos = cameraPosition + localPos;

        //if (isMissingNormal || isMissingTangent)
        //    material.normal = vec3(0.0, 0.0, 1.0);

        vec3 _viewNormal = normalize(viewNormal);
        vec3 _viewTangent = normalize(viewTangent);

        if (!gl_FrontFacing) {
            _viewNormal = -_viewNormal;
        }

        vec3 _viewBinormal = normalize(cross(_viewTangent, _viewNormal) * tangentW);

        if (!gl_FrontFacing) {
            _viewTangent = -_viewTangent;
            _viewBinormal = -_viewBinormal;
        }
        
        mat3 matTBN = mat3(_viewTangent, _viewBinormal, _viewNormal);

        PbrMaterial material;

        #if LAVA_TYPE == LAVA_FANCY && defined RENDER_TERRAIN
            if (materialId == MATERIAL_LAVA) {
                ApplyLavaMaterial(material, _viewNormal, worldPos, viewPos);
            }
            else {
        #endif
            PopulateMaterial(material, colorMap, normalMap.xyz, specularMap);

            #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
                #ifdef RENDER_ENTITIES
                    ApplyHardCodedMaterials(material, entityId);
                #elif defined RENDER_TERRAIN || defined RENDER_WATER
                    ApplyHardCodedMaterials(material, materialId, worldPos);
                #endif
            #else
                if (!isMissingNormal && !isMissingTangent) {
                    #if defined PARALLAX_ENABLED && !defined RENDER_TEXTURED
                        #if PARALLAX_SHAPE == PARALLAX_SHAPE_SHARP
                            float dO = max(texDepth - traceCoordDepth.z, 0.0);
                            if (dO >= 2.0 / 255.0) {
                                #ifdef PARALLAX_USE_TEXELFETCH
                                    material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                                #else
                                    material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                                #endif
                            }
                        #endif

                        #if defined SKY_ENABLED && defined PARALLAX_SHADOWS_ENABLED
                            if (traceCoordDepth.z + EPSILON < 1.0) {
                                vec3 tanLightDir = normalize(tanLightPos);
                                
                                #ifdef PARALLAX_USE_TEXELFETCH
                                    parallaxShadow *= GetParallaxShadow(traceCoordDepth, tanLightDir);
                                #else
                                    parallaxShadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);
                                #endif
                            }
                        #endif
                    #endif
                }
            #endif
        #if LAVA_TYPE == LAVA_FANCY && defined RENDER_TERRAIN
            }
        #endif

        #if AO_TYPE == AO_TYPE_VANILLA
            material.occlusion *= pow2(glcolor.a);
        #endif

        #if defined SKY_ENABLED && (WETNESS_MODE != WEATHER_MODE_NONE || SNOW_MODE != WEATHER_MODE_NONE) && (defined RENDER_TERRAIN || defined RENDER_WATER)
            if (isEyeInWater != 1 && materialId != MATERIAL_WATER && materialId != MATERIAL_LAVA) {
                vec3 tanUpDir = normalize(upPosition) * matTBN;
                float NoU = dot(material.normal, tanUpDir);

                ApplyWeather(material, NoU, viewDist, lm.x, lm.y);
            }
        #endif

        #ifdef RENDER_ENTITIES
            if (materialId == ENTITY_PHYSICSMOD_SNOW) {
                material.albedo.rgb = SNOW_COLOR;

                material.scattering = GetPhysicsSnowScattering(localPos);
                material.smoothness = GetPhysicsSnowSmooth(localPos);
                material.normal = GetPhysicsSnowNormal(localPos, viewDist);
                material.f0 = 0.02;
            }
        #endif

        #if defined RENDER_TERRAIN || defined RENDER_WATER
            if (materialId == 103) {
                material.albedo = vec4(1.0);
                material.albedo.rgb = RGBToLinear(vec3(0.212, 0.090, 0.082));
                material.smoothness = 0.6;
                material.scattering = 0.3;
                material.f0 = 0.034;
            }
        #endif

        // if (any(isnan(_viewNormal)))
        //     _viewNormal = vec3(0.0, 0.0, 1.0);

        #ifdef RENDER_TEXTURED
            material.normal = GetShadowLightViewDir();
        #else
            if (materialId != MATERIAL_LAVA)
                material.normal = normalize(matTBN * material.normal);
        #endif

        // WARN: disabling until this can be properly integrated out of water!
        // if (isEyeInWater == 1) {
        //     material.albedo.rgb = WetnessDarkenSurface(material.albedo.rgb, material.porosity, 1.0);
        // }

        #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
            if (!isMissingNormal && !isMissingTangent) {
                #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0 && !(defined RENDER_ENTITIES || defined RENDER_TEXTURED || defined RENDER_HAND)
                    ApplyDirectionalLightmap(lm.x, viewPos, viewNormal, material.normal);
                #endif
            }
        #endif

        WriteMaterial(material, colorMap, normalMap, specularMap);

        colorMapOut = vec4(colorMap.rgb, 1.0);
        normalMapOut = normalMap;
        specularMapOut = specularMap;
        lightingMapOut = vec4(lm, geoNoL * 0.5 + 0.5, parallaxShadow);
    }
#endif
