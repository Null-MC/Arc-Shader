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
        
        colorMap = texture2DGrad(texture, atlasCoord, dFdXY[0], dFdXY[1]) * glcolor;

        #ifndef RENDER_WATER
            if (colorMap.a < alphaTestRef) discard;
            colorMap.a = 1.0;
        #endif

        #ifdef PARALLAX_SMOOTH
            normalMap.xyw = SampleLinearRGB(normals, atlasCoord, 1.0 / atlasSize);
        #else
            normalMap.xyw = texture2DGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).rgb;
        #endif

        specularMap = texture2DGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);

        normalMap.xy = normalMap.xy * 2.0 - 1.0;
        normalMap.z = sqrt(max(1.0 - dot(normalMap.xy, normalMap.xy), EPSILON));

        #ifdef PARALLAX_SLOPE_NORMALS
            float dO = max(texDepth - traceCoordDepth.z, 0.0);
            if (dO >= 0.95 / 255.0) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    normalMap.xyz = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                #else
                    normalMap.xyz = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                #endif
            }
        #endif

        const float minSkylightThreshold = 1.0 / 32.0 + EPSILON;
        float shadow = step(minSkylightThreshold, lmcoord.y);

        #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
            #if SHADOW_TYPE == 3
                vec3 _shadowPos[4] = shadowPos;
            #else
                vec4 _shadowPos = shadowPos;
            #endif

            #if defined PARALLAX_ENABLED && defined PARALLAX_SHADOW_FIX
                // TODO: offset shadowmap by parallax view-dot-light
                //float depth = max(1.0 - traceCoordDepth.z, 0.0);
                //float lightDepth = depth / max(NoL, EPSILON);
                //shadowOffset = shadowViewDir * eyeDepth - lightDepth;
                // TODO: transform offset to shadow space?
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

            //shadow *= step(EPSILON, geoNoL);

            vec3 tanLightDir = normalize(tanLightPos);
            float NoL = dot(normalMap.xyz, tanLightDir);
            //shadow *= step(EPSILON, NoL);

            shadow *= step(EPSILON, geoNoL);
            shadow *= step(EPSILON, NoL);

            float lightSSS = 0.0;
            #ifdef SSS_ENABLED
                float materialSSS = GetLabPbr_SSS(specularMap.b);
                if (shadow > EPSILON || materialSSS > EPSILON)
                    shadow *= GetShadowing(_shadowPos, lightSSS);
            #else
                if (shadow > EPSILON) {
                    shadow *= GetShadowing(_shadowPos, lightSSS);

                    // #if SHADOW_COLORS == 1
                    //     vec3 shadowColor = GetShadowColor();

                    //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    //     //also make colors less intense when the block light level is high.
                    //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    //     lightColor *= shadowColor;
                    // #endif
                }
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

        normalMap.xyz = normalMap.xyz * matTBN * 0.5 + 0.5;

        lightingMap = vec4(lmcoord, shadow, lightSSS);
    }
#endif
