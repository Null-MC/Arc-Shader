#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 PbrLighting() {
        vec2 atlasCoord = texcoord;

        #ifdef PARALLAX_ENABLED
            float texDepth = 1.0;
            vec3 traceCoordDepth = vec3(1.0);
            vec3 tanViewDir = normalize(tanViewPos);

            #ifndef PARALLAX_USE_TEXELFETCH
                mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
            #endif

            if (viewPos.z < PARALLAX_DISTANCE) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    atlasCoord = GetParallaxCoord(tanViewDir, texDepth, traceCoordDepth);
                #else
                    atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, texDepth, traceCoordDepth);
                #endif
            }
        #endif

        PbrMaterial material;
        PopulateMaterial(atlasCoord, material);

        bool isWater = false;
        #ifndef RENDER_WATER
            if (material.albedo.a < alphaTestRef) discard;
        #else
            if (materialId == 1) {
                isWater = true;
                material.f0 = 0.02;
                material.smoothness = 0.96;
                material.normal = vec3(0.0, 0.0, 1.0);
            }
        #endif

        #ifdef PARALLAX_SLOPE_NORMALS
            if (!isWater) {
                float dO = max(texDepth - traceCoordDepth.z, 0.0);
                if (dO >= 0.95 / 255.0) {
                    #ifdef PARALLAX_USE_TEXELFETCH
                        material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                    #else
                        material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                    #endif
                }
            }
        #endif
        
        float shadow = step(EPSILON, geoNoL);// * step(1.0 / 32.0, skyLight);
        float NoL = 1.0;

        #ifdef SHADOW_ENABLED
            vec3 tanLightDir = normalize(tanLightPos);
            NoL = dot(material.normal, tanLightDir);
            shadow *= step(EPSILON, NoL);

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

        if (shadow > EPSILON) {
            #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
                shadow *= GetShadowing(shadowPos);

                // #if SHADOW_COLORS == 1
                //     vec3 shadowColor = GetShadowColor();

                //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                //     // make colors less intense when the block light level is high.
                //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                //     lightColor *= shadowColor;
                // #endif

                //skyLight = max(skyLight, shadow);
            #endif
        }

        float shadowSSS = 0.0;
        #ifdef SSS_ENABLED
            if (material.scattering > EPSILON) {
                shadowSSS = GetShadowSSS(shadowPos);
            }
        #endif

        material.normal = material.normal * matTBN;

        return PbrLighting2(material, lmcoord, shadow, shadowSSS, viewPos.xyz);
    }
#endif
