#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    void PbrLighting(out vec4 colorMap, out vec4 normalMap, out vec4 specularMap, out vec4 lightingMap, out vec3 shadowColorMap) {
        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        vec2 atlasCoord = texcoord;

        #ifdef PARALLAX_ENABLED
            float texDepth = 1.0;
            vec3 traceCoordDepth = vec3(1.0);
            vec3 tanViewDir = normalize(tanViewPos);

            float viewDist = length(viewPos);
            if (viewDist < PARALLAX_DISTANCE)
                atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);
        #endif
        
        #ifdef AF_ENABLED
            colorMap = textureAnisotropic(gtexture, atlasCoord, dFdXY);
        #else
            colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]);
        #endif

        #ifndef RENDER_WATER
            if (colorMap.a < alphaTestRef) discard;
            colorMap.a = 1.0;
        #endif

        colorMap.rgb *= glcolor.rgb;

        #ifdef RENDER_ENTITIES
            //colorMap.rgb *= (1.0 - entityColor.a) + entityColor.rgb * entityColor.a;
            colorMap.rgb = mix(colorMap.rgb, entityColor.rgb, entityColor.a);

            // TODO: fix lightning
        #endif

        vec3 normal = vec3(0.0, 0.0, 1.0);
        #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
            #ifdef PARALLAX_SMOOTH_NORMALS
                ////normalMap.rgb = TexelFetchLinearRGB(normals, atlasCoord * atlasSize);
                //normalMap.rgb = TextureGradLinearRGB(normals, atlasCoord, atlasSize, dFdXY);

                vec2 uv[4];
                //vec2 localCoord = GetLocalCoord(atlasCoord);
                //vec2 atlasTileSize = atlasBounds[1] * atlasSize;
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
                normalMap.rgb = TexelFetchLinearRGB(normals, iuv, 0, f);
            #else
                normalMap.rgb = textureGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).rgb;
                //normalMap.rgb = texture(normals, atlasCoord, wetness_lod).rgb;
            #endif

            specularMap = textureGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);

            normalMap.a = 1.0;
            if (normalMap.x + normalMap.y > EPSILON) {
                #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
                    normal = RestoreNormalZ(normalMap.xy);
                    normalMap.a = normalMap.b; // move AO to alpha
                #else
                    normal = normalMap.xyz;
                    normal.xy = normal.xy * 2.0 - 1.0;
                    //normal = normal * 2.0 - 1.0;
                    normal = normalize(normal);
                #endif
            }

            #ifdef PARALLAX_SLOPE_NORMALS
                float dO = max(texDepth - traceCoordDepth.z, 0.0);
                if (dO >= 2.0 / 255.0) {
                    #ifdef PARALLAX_USE_TEXELFETCH
                        normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                    #else
                        normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                    #endif
                }
            #endif

            #ifndef RENDER_ENTITIES
                float skyLight = saturate((lmcoord.y - (1.0/16.0 + EPSILON)) / (15.0/16.0));
                float wetnessFinal = GetDirectionalWetness(viewNormal, skyLight);

                // TODO: if wet, get additional 3 samples and mix?
                if (wetnessFinal > EPSILON) {
                    vec2 uv[4];
                    const int wetness_lod = 1;
                    vec2 atlasLodSize = atlasSize / exp2(wetness_lod);
                    vec2 f = GetLinearCoords(atlasCoord, atlasLodSize, uv);

                    uv[0] = GetAtlasCoord(GetLocalCoord(uv[0]));
                    uv[1] = GetAtlasCoord(GetLocalCoord(uv[1]));
                    uv[2] = GetAtlasCoord(GetLocalCoord(uv[2]));
                    uv[3] = GetAtlasCoord(GetLocalCoord(uv[3]));

                    // ivec2 iuv[4];
                    // iuv[0] = ivec2(uv[0] * atlasLodSize);
                    // iuv[1] = ivec2(uv[1] * atlasLodSize);
                    // iuv[2] = ivec2(uv[2] * atlasLodSize);
                    // iuv[3] = ivec2(uv[3] * atlasLodSize);

                    vec3 wetness_normal = TextureLinearRGB(normals, uv, wetness_lod, f);

                    if (wetness_normal.x + wetness_normal.y > EPSILON) {
                        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
                            wetness_normal = RestoreNormalZ(wetness_normal.xy);
                        #else
                            wetness_normal.xy = wetness_normal.xy * 2.0 - 1.0;
                            //wetness_normal = wetness_normal * 2.0 - 1.0;
                            wetness_normal = normalize(wetness_normal);
                        #endif
                    }
                    else wetness_normal = vec3(0.0, 0.0, 1.0);

                    normal = mix(normal, wetness_normal, wetnessFinal);
                    normal = normalize(normal);
                }
            #endif
        #else
            #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && defined RENDER_TERRAIN
                float sss = (0.25 + 0.75 * matSSS) * step(EPSILON, matSSS);
                specularMap = vec4(matSmooth, matF0, sss, 0.0);
            #else
                specularMap = vec4(0.08, 0.04, 0.0, 0.0);
            #endif
        #endif

        // #if defined SKY_ENABLED && defined LIGHTLEAK_FIX
        //     const float minSkylightThreshold = 1.0 / 16.0 + EPSILON;
        //     float shadow = step(minSkylightThreshold, lmcoord.y);
        // #else
        //     float shadow = 1.0;
        // #endif

        // float lightSSS = 0.0;
        // shadowColorMap = vec3(1.0);

        // #ifdef SSS_ENABLED
        //     float materialSSS = GetLabPbr_SSS(specularMap.b);
        // #endif

        // #ifdef SHADOW_ENABLED
        //     vec3 tanLightDir = normalize(tanLightPos);
        //     float NoL = dot(normal, tanLightDir);

        //     shadow *= step(EPSILON, geoNoL);
        //     shadow *= step(EPSILON, NoL);
            
        //     #if SHADOW_TYPE != SHADOW_TYPE_NONE
        //         #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //             vec3 _shadowPos[4] = shadowPos;
        //         #else
        //             vec4 _shadowPos = shadowPos;
        //         #endif

        //         #if defined PARALLAX_ENABLED && defined PARALLAX_SHADOW_FIX
        //             float depth = 1.0 - traceCoordDepth.z;
        //             float eyeDepth = 0.0; //depth / max(geoNoV, EPSILON);

        //             #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //                 _shadowPos[0] = mix(shadowPos[0], shadowParallaxPos[0], depth) - eyeDepth;
        //                 _shadowPos[1] = mix(shadowPos[1], shadowParallaxPos[1], depth) - eyeDepth;
        //                 _shadowPos[2] = mix(shadowPos[2], shadowParallaxPos[2], depth) - eyeDepth;
        //                 _shadowPos[3] = mix(shadowPos[3], shadowParallaxPos[3], depth) - eyeDepth;
        //             #else
        //                 _shadowPos = mix(shadowPos, shadowParallaxPos, depth) - eyeDepth;
        //             #endif
        //         #endif

        //         if (shadow > EPSILON) {
        //             #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //                 shadow *= GetShadowing(_shadowPos);
        //             #else
        //                 shadow *= GetShadowing(_shadowPos, shadowBias);
        //             #endif
        //         }

        //         #ifdef SHADOW_COLOR
        //             #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //                 shadowColorMap = GetShadowColor(shadowPos);
        //             #else
        //                 shadowColorMap = GetShadowColor(shadowPos.xyz, shadowBias);
        //             #endif
                    
        //             shadowColorMap = RGBToLinear(shadowColorMap);
        //         #endif

        //         #ifdef SSS_ENABLED
        //             if (materialSSS > EPSILON) {
        //                 #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //                     lightSSS = GetShadowSSS(_shadowPos);
        //                 #else
        //                     lightSSS = GetShadowSSS(_shadowPos, shadowBias);
        //                 #endif
        //             }
        //         #endif

        //         #ifdef PARALLAX_SHADOWS_ENABLED
        //             if (shadow > EPSILON && traceCoordDepth.z + EPSILON < 1.0) {
        //                 #ifdef PARALLAX_USE_TEXELFETCH
        //                     shadow *= GetParallaxShadow(traceCoordDepth, tanLightDir);
        //                 #else
        //                     shadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);
        //                 #endif
        //             }
        //         #endif
        //     #endif
        // #endif

        vec2 lm = lmcoord;

        // #if !defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE
        //     shadow = glcolor.a;

        //     // #ifdef SSS_ENABLED
        //     //     float skyLight = saturate((lm.y - (0.5/16.0)) / (15.0/16.0));
        //     //     lightSSS = skyLight * materialSSS;
        //     // #endif
        // #endif

        vec3 _viewNormal = normalize(viewNormal);
        vec3 _viewTangent = normalize(viewTangent);
        vec3 _viewBinormal = normalize(cross(_viewTangent, _viewNormal) * tangentW);
        mat3 matTBN = mat3(_viewTangent, _viewBinormal, _viewNormal);

        vec3 texViewNormal = normalize(matTBN * normal);

        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0 && MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
            ApplyDirectionalLightmap(lm.x, texViewNormal);
        #endif

        normalMap.xyz = texViewNormal * 0.5 + 0.5;

        lightingMap = vec4(lm, geoNoL, 0.0);
    }
#endif
