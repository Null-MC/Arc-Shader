#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    void PbrLighting(out vec4 colorMapOut, out vec4 normalMapOut, out vec4 specularMapOut, out vec4 lightingMapOut) {
        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        vec4 colorMap, normalMap, specularMap;

        normalMap.xyz = textureGrad(normals, texcoord, dFdXY[0], dFdXY[1]).xyz;
        bool isMissingNormal = all(lessThan(normalMap.xy, vec2(EPSILON)));
        bool isMissingTangent = any(isnan(viewTangent));

        vec2 atlasCoord = texcoord;
        float viewDist = length(viewPos);

        #ifdef PARALLAX_ENABLED
            bool skipParallax = isMissingTangent || isMissingNormal;

            #ifdef RENDER_ENTITIES
                if (entityId == MATERIAL_ITEM_FRAME || entityId == MATERIAL_PHYSICS_SNOW) skipParallax = true;
            #else
                if (materialId == MATERIAL_LAVA) skipParallax = true;
            #endif

            float texDepth = 1.0;
            vec3 traceCoordDepth = vec3(1.0);
            vec3 tanViewDir = normalize(tanViewPos);

            if (!skipParallax && viewDist < PARALLAX_DISTANCE) {
                atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);

                #ifndef PARALLAX_SMOOTH_NORMALS
                    normalMap.xyz = textureGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).xyz;
                #endif

                #ifdef PARALLAX_DEPTH_WRITE
                    float pomDist = (1.0 - traceCoordDepth.z) / max(-tanViewDir.z, 0.00001);

                    if (pomDist > 0.0) {
                        //float depth = linearizePerspectiveDepth(gl_FragCoord.z, gbufferProjection);
                        //gl_FragDepth = delinearizePerspectiveDepth(depth + pomDist * (0.25 * PARALLAX_DEPTH), gbufferProjection);
                        float depth = -viewPos.z + pomDist * PARALLAX_DEPTH;
                        gl_FragDepth = 0.5 * (-gbufferProjection[2].z*depth + gbufferProjection[3].z) / depth + 0.5;
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
        
        #ifdef AF_ENABLED
            colorMap = textureAnisotropic(gtexture, atlasCoord, dFdXY);
        #else
            colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]);
        #endif

        #ifndef RENDER_WATER
            if (colorMap.a < 10.0/255.0) discard;
        #endif

        colorMap.rgb *= glcolor.rgb;

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

        #if defined PARALLAX_SMOOTH_NORMALS && MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
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

        PbrMaterial material;
        PopulateMaterial(material, colorMap, normalMap.xyz, specularMap);

        if (!isMissingNormal && !isMissingTangent) {
            #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
                #ifdef PARALLAX_SLOPE_NORMALS
                    float dO = max(texDepth - traceCoordDepth.z, 0.0);
                    if (dO >= 2.0 / 255.0) {
                        #ifdef PARALLAX_USE_TEXELFETCH
                            material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                        #else
                            material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                        #endif
                    }
                #endif
            #else
                #ifdef RENDER_TERRAIN
                    material.f0 = matF0;
                    material.smoothness = matSmooth;
                    material.scattering = matSSS;
                #else
                    material.f0 = 0.04;
                    material.smoothness = 0.08;
                #endif
            #endif

            #if AO_TYPE == AO_TYPE_VANILLA
                material.occlusion *= pow2(glcolor.a);
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

            #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0 && MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT && !defined RENDER_ENTITIES
                ApplyDirectionalLightmap(lm.x, material.normal);
            #endif
        }

        if (isMissingNormal || isMissingTangent) {
            material.normal = vec3(0.0, 0.0, 1.0);
        }

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

        #if defined SKY_ENABLED && (WETNESS_MODE != WEATHER_MODE_NONE || SNOW_MODE != WEATHER_MODE_NONE) && !defined RENDER_ENTITIES && !defined RENDER_HAND
            if (isEyeInWater != 1) {
                vec3 tanUpDir = normalize(upPosition) * matTBN;
                float NoU = dot(material.normal, tanUpDir);

                ApplyWeather(material, NoU, viewDist, lm.x, lm.y);
            }
        #endif

        material.normal = normalize(matTBN * material.normal);

        #ifdef RENDER_ENTITIES
            if (materialId == MATERIAL_PHYSICS_SNOW) {
                colorMap.rgb = SNOW_COLOR;

                material.scattering = GetPhysicsSnowScattering(localPos);
                material.smoothness = GetPhysicsSnowSmooth(localPos);
                material.normal = GetPhysicsSnowNormal(localPos, material.normal, viewDist);
                material.f0 = 0.02;
            }
        #endif

        if (isEyeInWater == 1) {
            material.albedo.rgb = WetnessDarkenSurface(material.albedo.rgb, material.porosity, 1.0);
        }

        WriteMaterial(material, colorMap, normalMap, specularMap);

        colorMapOut = vec4(colorMap.rgb, 1.0);
        normalMapOut = normalMap;
        specularMapOut = specularMap;
        lightingMapOut = vec4(lm, geoNoL * 0.5 + 0.5, parallaxShadow);
    }
#endif
