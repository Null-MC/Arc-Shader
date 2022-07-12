#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    void PbrLighting(out vec4 colorMap, out vec4 normalMap, out vec4 specularMap, out vec4 lightingMap) {
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
            colorMap = texture2DGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]);
        #endif

        #ifndef RENDER_WATER
            if (colorMap.a < alphaTestRef) discard;
            colorMap.a = 1.0;
        #endif

        colorMap *= glcolor;

        #ifdef RENDER_ENTITIES
            //colorMap.rgb *= (1.0 - entityColor.a) + entityColor.rgb * entityColor.a;
            colorMap.rgb = mix(colorMap.rgb, entityColor.rgb, entityColor.a);
        #endif

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
            normalMap.rgb = texture2DGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).rgb;
        #endif

        normalMap.a = 0.0;

        specularMap = texture2DGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);

        vec3 normal = RestoreNormalZ(normalMap.xy);

        #ifdef PARALLAX_SLOPE_NORMALS
            float dO = max(texDepth - traceCoordDepth.z, 0.0);
            if (dO >= 0.95 / 255.0) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                #else
                    normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                #endif
            }
        #endif

        const float minSkylightThreshold = 1.0 / 32.0 + EPSILON;
        float shadow = step(minSkylightThreshold, lmcoord.y);
        float lightSSS = 0.0;

        #if defined SHADOW_ENABLED
            vec3 tanLightDir = normalize(tanLightPos);
            float NoL = dot(normal, tanLightDir);

            shadow *= step(EPSILON, geoNoL);
            shadow *= step(EPSILON, NoL);
            
            #if SHADOW_TYPE != 0
                #if SHADOW_TYPE == 3
                    vec3 _shadowPos[4] = shadowPos;
                #else
                    vec4 _shadowPos = shadowPos;
                #endif

                #if defined PARALLAX_ENABLED && defined PARALLAX_SHADOW_FIX
                    float depth = 1.0 - traceCoordDepth.z;
                    float eyeDepth = 0.0; //depth / max(geoNoV, EPSILON);

                    #if SHADOW_TYPE == 3
                        _shadowPos[0] = mix(shadowPos[0], shadowParallaxPos[0], depth) - eyeDepth;
                        _shadowPos[1] = mix(shadowPos[1], shadowParallaxPos[1], depth) - eyeDepth;
                        _shadowPos[2] = mix(shadowPos[2], shadowParallaxPos[2], depth) - eyeDepth;
                        _shadowPos[3] = mix(shadowPos[3], shadowParallaxPos[3], depth) - eyeDepth;
                    #else
                        _shadowPos = mix(shadowPos, shadowParallaxPos, depth) - eyeDepth;
                    #endif
                #endif


                if (shadow > EPSILON) {
                    shadow *= GetShadowing(_shadowPos);

                    // #if SHADOW_COLORS == 1
                    //     vec3 shadowColor = GetShadowColor();

                    //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    //     //also make colors less intense when the block light level is high.
                    //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    //     lightColor *= shadowColor;
                    // #endif
                }

                #ifdef SSS_ENABLED
                    float materialSSS = GetLabPbr_SSS(specularMap.b);
                    if (materialSSS > EPSILON)
                        lightSSS = GetShadowSSS(_shadowPos);
                #endif

                #ifdef PARALLAX_SHADOWS_ENABLED
                    if (shadow > EPSILON && traceCoordDepth.z + EPSILON < 1.0) {
                        #ifdef PARALLAX_USE_TEXELFETCH
                            shadow *= GetParallaxShadow(traceCoordDepth, tanLightDir);
                        #else
                            shadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);
                        #endif
                    }
                #endif
            #endif
        #endif
        
        vec2 lm = lmcoord;
        #ifdef DIRECTIONAL_LIGHTMAP
            vec3 texViewNormal = normalize(normal.xyz * matTBN);
            ApplyDirectionalLightmap(lm.x, texViewNormal);
        #endif

        #ifdef RENDER_WATER
            // TODO: blend in deferred output?
        #endif

        normalMap.xy = (normal.xyz * matTBN).xy * 0.5 + 0.5;

        lightingMap = vec4(lm, shadow, lightSSS);
    }
#endif
