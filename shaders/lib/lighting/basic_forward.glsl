vec4 BasicLighting(const in LightData lightData, const in vec4 albedo, const in vec3 viewNormal) {
    float shadow = step(EPSILON, lightData.geoNoL);
    //shadow *= step(1.0 / 32.0, lightData.skyLight);

    float skyLight = lightData.skyLight;
    vec3 shadowColor = vec3(1.0);

    vec3 worldPos = cameraPosition + localPos;
    vec3 localViewDir = normalize(localPos);

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if defined SHADOW_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER)
            if (shadow > EPSILON) {
                shadow *= GetShadowing(lightData);

                if (isEyeInWater != 1)
                    skyLight = max(skyLight, shadow);
            }

            #ifdef SHADOW_COLOR
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    if (lightData.shadowPos[lightData.shadowCascade].z - lightData.transparentShadowDepth > lightData.shadowBias[lightData.shadowCascade])
                        shadowColor = GetShadowColor(lightData.shadowPos[lightData.shadowCascade].xy);
                #else
                    if (lightData.shadowPos.z - lightData.transparentShadowDepth > lightData.shadowBias)
                        shadowColor = GetShadowColor(lightData.shadowPos.xy);
                #endif
            #endif
        
            #ifdef SHADOW_CLOUD
                vec3 localLightDir = GetShadowLightLocalDir();
                float cloudF = GetCloudFactor(worldPos, localLightDir, 0);
                shadow *= 1.0 - cloudF;
            #endif
        #endif
    #else
        shadow = glcolor.a;
    #endif

    #ifdef LIGHTLEAK_FIX
        // Make areas without skylight fully shadowed (light leak fix)
        float lightLeakFix = step(skyLight, EPSILON);
        shadow *= lightLeakFix;
    #endif

    float skyLight2 = pow2(skyLight);
    float skyLight3 = pow3(skyLight);

    vec3 ambient = vec3(MinWorldLux);
    vec3 diffuse = vec3(0.0);

    #ifndef RENDER_WEATHER
        diffuse += albedo.rgb * pow3(lightData.blockLight) * blockLightColor;
    #endif

    vec3 waterExtinctionInv = 1.0 - waterAbsorbColor;

    //vec3 skyAmbient = vec3(pow(skyLight, 5.0));
    #ifdef SKY_ENABLED
        #ifdef RENDER_WEATHER
            vec3 skyColorLux = RGBToLinear(skyColor);// * skyTint;
            skyColorLux = 20000.0 * skyColorLux;
            vec3 skyAmbient = skyColorLux * max(skyLightLevels.x, 0.0);
        #else
            vec3 localNormal = mat3(gbufferModelViewInverse) * viewNormal;
            vec3 skyAmbient = GetFancySkyAmbientLight(localNormal) * smoothstep(0.0, 1.0, skyLight);

            vec3 sunColorFinal = lightData.sunTransmittance * skySunColor * SunLux;// * GetSunLux();
            vec3 moonColorFinal = lightData.moonTransmittance * skyMoonColor * MoonLux * GetMoonPhaseLevel();// * GetMoonLux();
            vec3 skyLightColor = 0.2 * (sunColorFinal + moonColorFinal);

            if (isEyeInWater == 1) {
                vec3 sunAbsorption = exp(-max(lightData.waterShadowDepth, 0.0) * waterExtinctionInv) * shadow;
                vec3 viewAbsorption = exp(-max(lightData.opaqueScreenDepthLinear, 0.0) * waterExtinctionInv);

                // #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                //     if (lightData.opaqueShadowDepth < lightData.shadowPos[lightData.shadowCascade].z - lightData.shadowBias[lightData.shadowCascade])
                //         sunAbsorption = 1.0 - (1.0 - sunAbsorption) * (1.0 - ShadowBrightnessF);
                // #else
                //     if (lightData.opaqueShadowDepth < lightData.shadowPos.z - lightData.shadowBias)
                //         sunAbsorption = 1.0 - (1.0 - sunAbsorption) * (1.0 - ShadowBrightnessF);
                // #endif

                skyAmbient *= viewAbsorption;
                skyLightColor *= sunAbsorption;
            }

            diffuse += albedo.rgb * lightData.geoNoL * skyLightColor * shadowColor * shadow;
        #endif

        ambient += skyAmbient;
    #endif

    #if defined HANDLIGHT_ENABLED && !defined RENDER_HAND
        if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
            vec3 handViewPos = viewPos.xyz;

            #ifdef IS_IRIS
                if (!firstPersonCamera) {
                    vec3 playerCameraOffset = cameraPosition - eyePosition;
                    playerCameraOffset = (gbufferModelView * vec4(playerCameraOffset, 1.0)).xyz;
                    handViewPos += playerCameraOffset;
                }
            #endif

            diffuse += ApplyHandLighting(albedo.rgb, handViewPos);
        }
    #endif

    vec4 final = albedo;
    final.rgb *= ambient;
    final.rgb += diffuse;

    float viewDist = length(viewPos);
    vec3 viewDir = viewPos / viewDist;

    #ifdef SKY_ENABLED
        vec3 sunColorFinalEye = sunTransmittanceEye * skySunColor * SunLux;
        vec3 moonColorFinalEye = moonTransmittanceEye * skyMoonColor * MoonLux * GetMoonPhaseLevel();

        #ifdef RENDER_WEATHER
            vec3 sunDir = GetSunViewDir();
            float sun_VoL = dot(viewDir, sunDir);
            float rainSnowSunVL = mix(
                ComputeVolumetricScattering(sun_VoL, -0.16),
                ComputeVolumetricScattering(sun_VoL, 0.66),
                0.3);

            vec3 moonDir = GetMoonViewDir();
            float moon_VoL = dot(viewDir, moonDir);
            float rainSnowMoonVL = mix(
                ComputeVolumetricScattering(moon_VoL, -0.16),
                ComputeVolumetricScattering(moon_VoL, 0.66),
                0.3);

            vec3 weatherLightColor = 6.0 * 
                max(rainSnowSunVL, 0.0) * sunColorFinalEye +
                max(rainSnowMoonVL, 0.0) * moonColorFinalEye;

            //float alpha = mix(WEATHER_OPACITY * 0.01, 1.0, saturate(max(rainSnowSunVL, rainSnowMoonVL)));

            final.rgb += albedo.rgb * weatherLightColor * (0.2 + 0.8 * shadow);
            final.a = albedo.a * rainStrength * (WEATHER_OPACITY * 0.01);
        #else
            if (isEyeInWater == 1) {
                vec3 viewAbsorption = exp(-viewDist * waterExtinctionInv);
                final.rgb *= viewAbsorption;
            }
        #endif
    #endif

    #ifdef WORLD_WATER_ENABLED
        if (isEyeInWater == 1) {
            #ifdef SKY_ENABLED
                vec3 waterSunColorEye = sunColorFinalEye * max(skyLightLevels.x, 0.0);
                vec3 waterMoonColorEye = moonColorFinalEye * max(skyLightLevels.y, 0.0);
                vec2 waterScatteringF = GetWaterScattering(viewDir);

                vec3 waterFogColor = GetWaterFogColor(waterSunColorEye, waterMoonColorEye, waterScatteringF);
            #else
                vec3 waterFogColor = vec3(0.0);
            #endif

            ApplyWaterFog(final.rgb, waterFogColor, viewDist);

            #if defined SKY_ENABLED && defined SHADOW_ENABLED && defined WATER_VL_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                vec3 vlScatter, vlExt;
                GetWaterVolumetricLighting(vlScatter, vlExt, waterScatteringF, localViewDir, near, viewDist);
                final.rgb = final.rgb * vlExt + vlScatter;
            #endif
        }
        else {
    #endif

        #if defined SKY_ENABLED && !defined SKY_VL_ENABLED
            vec3 viewLightDir = GetShadowLightViewDir();
            float VoL = dot(viewLightDir, viewDir);
            vec3 localSunDir = GetSunLocalDir();
            vec4 scatteringTransmittance = GetFancyFog(localPos, localSunDir, VoL);
            final.rgb = final.rgb * scatteringTransmittance.a + scatteringTransmittance.rgb;
        #elif !defined SKY_ENABLED
            float fogFactor;
            vec3 fogColorFinal;
            GetFog(lightData, worldPos, viewPos, fogColorFinal, fogFactor);
            ApplyFog(final, fogColorFinal, fogFactor, 1.0/255.0);
        #endif

        #ifdef SKY_ENABLED
            #if defined WORLD_CLOUDS_ENABLED && SKY_CLOUD_LEVEL > 0
                float cloudDepthTest = SKY_CLOUD_LEVEL - worldPos.y;
                cloudDepthTest *= sign(SKY_CLOUD_LEVEL - cameraPosition.y);

                if (HasClouds(cameraPosition, localViewDir) && cloudDepthTest < 0.0) {
                    vec3 cloudPos = GetCloudPosition(cameraPosition, localViewDir);
                    float cloudF = GetCloudFactor(cloudPos, localViewDir, 0);

                    // vec3 sunDir = GetSunDir();
                    // float sun_VoL = dot(viewDir, sunDir);

                    // vec3 moonDir = GetMoonDir();
                    // float moon_VoL = dot(viewDir, moonDir);

                    vec3 cloudColor = GetCloudColor(cloudPos, localViewDir, skyLightLevels);

                    //cloudF = smoothstep(0.0, 1.0, cloudF);
                    //final.rgb = mix(final.rgb, cloudColor, cloudF);
                    // TODO: mix opacity?
                }
            #endif

            #if defined SKY_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                vec3 vlScatter, vlExt;
                GetVolumetricLighting(vlScatter, vlExt, localViewDir, near, viewDist);
                final.rgb = final.rgb * vlExt + vlScatter;

                // TODO: vl alter alpha?
            #endif
        #endif

    #ifdef WORLD_WATER_ENABLED
        }
    #endif

    return final;
}
