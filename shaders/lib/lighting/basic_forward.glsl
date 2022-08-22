#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 BasicLighting() {
        vec4 albedo = texture(gtexture, texcoord);
        if (albedo.a < (0.5/255.0)) discard;

        //#if !defined RENDER_TEXTURED && !defined RENDER_WEATHER
        //    if (albedo.a < alphaTestRef) discard;
        //#endif

        albedo.rgb = RGBToLinear(albedo.rgb * glcolor.rgb);
        albedo.a *= PARTICLE_OPACITY;

        float blockLight = clamp((lmcoord.x - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
        float skyLight = clamp((lmcoord.y - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);

        //blockLight = blockLight*blockLight*blockLight;
        //skyLight = skyLight*skyLight*skyLight;

        float shadow = step(EPSILON, geoNoL) * step(1.0 / 32.0, skyLight);
        //vec3 lightColor = skyLightColor;

        vec3 skyAmbient = vec3(pow(skyLight, 5.0));
        #ifdef SKY_ENABLED
            float skyLight2 = pow2(skyLight);
            float ambientBrightness = mix(0.36 * skyLight2, 0.95 * skyLight, rainStrength); // SHADOW_BRIGHTNESS
            skyAmbient *= GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;
        #endif

        float blockAmbient = pow(blockLight, 5.0) * BlockLightLux;
        vec3 ambient = 0.1 + blockAmbient + skyAmbient;
        vec3 diffuse = vec3(0.0);

        vec3 shadowColorMap = vec3(1.0);
        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if defined SHADOW_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER)
                if (shadow > EPSILON) {
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        shadow *= GetShadowing(shadowPos);
                    #else
                        shadow *= GetShadowing(shadowPos, shadowBias);
                    #endif

                    // #if SHADOW_COLORS == 1
                    //     vec3 shadowColor = GetShadowColor();

                    //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    //     //also make colors less intense when the block light level is high.
                    //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    //     lightColor *= shadowColor;
                    // #endif

                    skyLight = max(skyLight, shadow);
                }

                #ifdef SHADOW_COLOR
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        shadowColorMap = GetShadowColor(shadowPos);
                    #else
                        shadowColorMap = GetShadowColor(shadowPos.xyz, shadowBias);
                    #endif
                    
                    shadowColorMap = RGBToLinear(shadowColorMap);
                #endif
            #endif
        #else
            shadow = glcolor.a;
        #endif

        #ifdef SKY_ENABLED
            diffuse += albedo.rgb * skyLightColor * shadowColorMap * shadow;
        #endif

        #if defined HANDLIGHT_ENABLED && !defined RENDER_HAND && !defined RENDER_HAND_WATER
            if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
                const float roughL = 1.0;
                const float scattering = 0.0;
                diffuse += ApplyHandLighting(albedo.rgb, viewPos.xyz);
            }
        #endif

        vec4 final = albedo;
        final.rgb *= ambient;
        final.rgb += diffuse;

        ApplyFog(final, viewPos, skyLight, EPSILON);

        #if defined SKY_ENABLED && defined VL_ENABLED && (defined VL_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER))
            mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
            vec3 shadowViewStart = (matViewToShadowView * vec4(vec3(0.0, 0.0, -near), 1.0)).xyz;
            vec3 shadowViewEnd = (matViewToShadowView * vec4(viewPos, 1.0)).xyz;

            PbrLightData lightData;
            // TODO: add CSM projections

            vec2 skyLightLevels = GetSkyLightLevels();
            float sunLightLevel = GetSunLightLevel(skyLightLevels.x);
            float vlScatter = GetScatteringFactor(sunLightLevel);

            #ifdef SHADOW_COLOR
                vec3 volScatter = GetVolumetricLightingColor(lightData, shadowViewStart, shadowViewEnd, vlScatter);
            #else
                float volScatter = GetVolumetricLighting(lightData, shadowViewStart, shadowViewEnd, vlScatter);
            #endif

            final.rgb += volScatter * (sunColor + moonColor);
        #endif

        return final;
    }
#endif
