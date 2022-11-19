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

        //colorMap.rgb = RGBToLinear(colorMap.rgb);

        //vec3 normal = vec3(0.0, 0.0, 1.0);
        float parallaxShadow = 1.0;
        //float occlusion = 1.0;
        vec2 lm = lmcoord;

        // #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
        //     material.occlusion = normalMap.b;
        // #endif

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
                //occlusion = normalMap.b;
            }
        #endif

        PbrMaterial material;
        PopulateMaterial(material, colorMap, normalMap.xyz, specularMap);

        if (!isMissingNormal && !isMissingTangent) {
            #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
                // if (normalMap.x + normalMap.y > EPSILON) {
                //     #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
                //         normal = GetLabPbr_Normal(normalMap.xy);
                //         //normalMap.a = normalMap.b; // move AO to alpha
                //     #else
                //         normal = GetOldPbr_Normal(normalMap);
                //     #endif
                // }

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

                //float skyLight = 0.0;
                // #if defined SKY_ENABLED && defined WETNESS_SMOOTH_NORMAL && !defined RENDER_ENTITIES
                //     skyLight = saturate((lmcoord.y - (1.0/16.0 + EPSILON)) / (15.0/16.0));
                //     float wetnessFinal = GetDirectionalWetness(viewNormal, skyLight);

                //     // TODO: if wet, get additional 3 samples and mix?
                //     if (wetnessFinal > EPSILON) {
                //         vec2 uv[4];
                //         const int wetness_lod = 1;
                //         vec2 atlasLodSize = atlasSize / exp2(wetness_lod);
                //         vec2 f = GetLinearCoords(atlasCoord, atlasLodSize, uv);

                //         uv[0] = GetAtlasCoord(GetLocalCoord(uv[0]));
                //         uv[1] = GetAtlasCoord(GetLocalCoord(uv[1]));
                //         uv[2] = GetAtlasCoord(GetLocalCoord(uv[2]));
                //         uv[3] = GetAtlasCoord(GetLocalCoord(uv[3]));

                //         // ivec2 iuv[4];
                //         // iuv[0] = ivec2(uv[0] * atlasLodSize);
                //         // iuv[1] = ivec2(uv[1] * atlasLodSize);
                //         // iuv[2] = ivec2(uv[2] * atlasLodSize);
                //         // iuv[3] = ivec2(uv[3] * atlasLodSize);

                //         vec3 wetness_normal = TextureLinearRGB(normals, uv, wetness_lod, f);

                //         if (wetness_normal.x + wetness_normal.y > EPSILON) {
                //             #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
                //                 wetness_normal = RestoreNormalZ(wetness_normal.xy);
                //             #else
                //                 wetness_normal.xy = wetness_normal.xy * 2.0 - 1.0;
                //                 //wetness_normal = wetness_normal * 2.0 - 1.0;
                //                 wetness_normal = normalize(wetness_normal);
                //             #endif
                //         }
                //         else wetness_normal = vec3(0.0, 0.0, 1.0);

                //         normal = mix(normal, wetness_normal, wetnessFinal);
                //         normal = normalize(normal);
                //     }
                // #endif
            #else
                #ifdef RENDER_TERRAIN
                    //float sss = (0.25 + 0.75 * matSSS) * step(EPSILON, matSSS);
                    //specularMap = vec4(matSmooth, matF0, sss, 0.0);

                    material.f0 = matF0;
                    material.smoothness = matSmooth;
                    material.scattering = matSSS;
                #else
                    //specularMap = vec4(0.08, 0.04, 0.0, 0.0);

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

        vec3 _viewNormal = normalize(viewNormal);

        if (!gl_FrontFacing)
            _viewNormal = -_viewNormal;

        if ((isMissingNormal || isMissingTangent) && dot(viewNormal, viewNormal) > 0.1) {
            material.normal = _viewNormal;
        }
        else {
            vec3 _viewTangent = normalize(viewTangent);
            vec3 _viewBinormal = normalize(cross(_viewTangent, _viewNormal) * tangentW);

            if (!gl_FrontFacing) {
                _viewTangent = -_viewTangent;
                _viewBinormal = -_viewBinormal;
            }
            
            mat3 matTBN = mat3(_viewTangent, _viewBinormal, _viewNormal);

            material.normal = normalize(matTBN * material.normal);
        }

        // else {
        //     // fix sign, map, nametag normals
        //     vec3 dX = dFdx(viewPos);
        //     vec3 dY = dFdy(viewPos);
        //     normal = normalize(cross(dX, dY));
        //     occlusion = 1.0;
        // }

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

        #if defined SKY_ENABLED && !defined RENDER_ENTITIES && !defined RENDER_HAND
            if (isEyeInWater != 1) {
                #ifdef WETNESS_ENABLED
                    if (biomeWetness > EPSILON) {
                        vec3 waterLocalPos = cameraPosition + localPos;
                        vec2 waterTex = waterLocalPos.xz + vec2(0.08, 0.02) * waterLocalPos.y;

                        float noise1 = textureLod(noisetex, 0.01*waterTex, 0).r;
                        float noise2 = 1.0 - textureLod(noisetex, 0.05*waterTex, 0).r;
                        float noise3 = textureLod(noisetex, 0.20*waterTex, 0).r;

                        float wetnessFinal = GetDirectionalWetness(material.normal, lm.y);

                        if (wetnessFinal > EPSILON) {
                            float areaWetness = saturate(biomeWetness * wetnessFinal * 
                                (1.00 * noise1 + 0.50 * noise2 + 0.25 * noise3));

                            material.albedo.rgb = WetnessDarkenSurface(material.albedo.rgb, material.porosity, areaWetness);

                            float puddleF = smoothstep(0.7, 0.8, areaWetness);// * pow2(wetnessFinal);

                            vec3 viewUpDir = normalize(upPosition);
                            material.normal = mix(material.normal, viewUpDir, puddleF);
                            material.normal = normalize(material.normal);
                            
                            float surfaceWetness = GetSurfaceWetness(areaWetness, material.porosity);
                            surfaceWetness = max(surfaceWetness, puddleF);

                            material.smoothness = mix(material.smoothness, WATER_SMOOTH, surfaceWetness);
                            material.f0 = mix(material.f0, 0.02, surfaceWetness * (1.0 - material.f0));
                        }
                    }
                #endif

                #ifdef SNOW_ENABLED
                    if (biomeSnow > EPSILON) {
                        vec3 snowLocalPos = cameraPosition + localPos;
                        vec2 snowTex = snowLocalPos.xz + snowLocalPos.y;

                        float noise1 = 1.0 - textureLod(noisetex, 0.01*snowTex, 0).r;
                        float noise2 = 1.0 - textureLod(noisetex, 0.05*snowTex, 0).r;
                        float noise3 = textureLod(noisetex, 0.20*snowTex, 0).r;

                        float snowFinal = GetDirectionalSnow(material.normal, lm.y);
                        //snowFinal = min(snowFinal + (1.0 - occlusion), 1.0);

                        float areaSnow = saturate(2.0 * snowFinal * biomeSnow *
                            (1.00 * noise1 + 0.50 * noise2 + 0.25 * noise3));

                        material.albedo.rgb = mix(material.albedo.rgb, SNOW_COLOR, areaSnow);
                        material.smoothness = mix(material.smoothness, 0.48, areaSnow);

                        if (areaSnow > 0.1) {
                            material.hcm = -1;
                            material.f0 = 0.04;

                            vec2 localTex = (texcoord - atlasBounds[0]) * atlasSize;
                            vec3 snowNormal = normalize(hash32(uvec2(localTex)));
                            snowNormal *= sign(dot(snowNormal, material.normal));

                            material.normal = normalize(mix(material.normal, snowNormal, 0.3));
                        }
                    }
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
