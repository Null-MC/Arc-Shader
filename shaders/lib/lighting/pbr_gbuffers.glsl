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

            if (viewPos.z < PARALLAX_DISTANCE) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    atlasCoord = GetParallaxCoord(tanViewDir, texDepth, traceCoordDepth);
                #else
                    atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, texDepth, traceCoordDepth);
                #endif
            }
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

        #ifdef PARALLAX_SMOOTH
            #ifdef PARALLAX_USE_TEXELFETCH
                normalMap.rgb = TexelFetchLinearRGB(normals, atlasCoord * atlasSize);
            #else
                normalMap.rgb = TextureGradLinearRGB(normals, atlasCoord, atlasSize, dFdXY);
            #endif
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

        #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
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

            vec3 tanLightDir = normalize(tanLightPos);
            float NoL = dot(normal, tanLightDir);

            shadow *= step(EPSILON, geoNoL);
            shadow *= step(EPSILON, NoL);

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
        
        #ifdef RENDER_WATER
            // TODO: blend in deferred output?
        #endif

        normalMap.xy = (normal.xyz * matTBN).xy * 0.5 + 0.5;

        lightingMap = vec4(lmcoord, shadow, lightSSS);
    }
#endif
