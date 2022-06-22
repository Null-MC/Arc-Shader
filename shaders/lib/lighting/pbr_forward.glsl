#ifdef RENDER_VERTEX
#endif

#ifdef RENDER_FRAG
    const vec3 minLight = vec3(0.01);
    const float lmPadding = 1.0 / 32.0;

    vec4 PbrLighting() {
        vec2 atlasCoord = texcoord;
        float blockLight = lmcoord.x - (0.5/16.0) / (15.0/16.0);
        float skyLight = lmcoord.y - (0.5/16.0) / (15.0/16.0);

        blockLight *= blockLight;
        skyLight *= skyLight;

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

        #ifndef RENDER_WATER
            if (material.albedo.a < alphaTestRef) discard;
        #endif

        #ifdef PARALLAX_SLOPE_NORMALS
            float dO = max(texDepth - traceCoordDepth.z, 0.0);
            if (dO >= 0.95 / 255.0) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                #else
                    material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                #endif
            }
        #endif

        float shadow = step(EPSILON, geoNoL) * step(1.0 / 32.0, skyLight);
        vec3 lightColor = skyLightColor;
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

        vec3 lmValue = vec3(1.0);
        if (shadow > EPSILON) {
            #ifdef SHADOW_ENABLED
                shadow *= GetShadowing(shadowPos);

                #if SHADOW_COLORS == 1
                    vec3 shadowColor = GetShadowColor();

                    shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    // make colors less intense when the block light level is high.
                    shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    lightColor *= shadowColor;
                #endif

                skyLight = max(skyLight, shadow);
            #endif
        }
        //else {
        //    skyLight = 0.0;
        //}

        vec4 final = material.albedo;

        vec2 ambientLMCoord = vec2(blockLight, skyLight) * (15.0/16.0) + (0.5/16.0);
        vec3 ambientLM = RGBToLinear(texture2D(lightmap, ambientLMCoord).rgb);

        // vec2 lmSkyCoord = vec2(0.0, skyLight * (15.0/16.0)) + (0.5/16.0);
        // vec3 lightSky = RGBToLinear(texture2D(lightmap, lmSkyCoord).rgb);

        vec3 ambient = minLight + 0.3 * ambientLM * material.occlusion;
        vec3 diffuse = max(NoL, 0.0) * lightColor * shadow;
        float emissive = material.emission;
        final.rgb *= (ambient + diffuse + emissive);

        #ifdef RENDER_WATER
            ApplyFog(final, viewPos, EPSILON);
        #else
            ApplyFog(final, viewPos, alphaTestRef);
        #endif

        return final;
    }
#endif
