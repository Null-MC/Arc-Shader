vec4 BasicLighting(const in LightData lightData, const in vec4 albedo, const in vec3 viewNormal) {
    float shadow = step(EPSILON, lightData.geoNoL);
    //shadow *= step(1.0 / 32.0, lightData.skyLight);

    float skyLight = lightData.skyLight;
    vec3 shadowColor = vec3(1.0);

    vec3 worldPos = cameraPosition + localPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if defined SHADOW_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER)
            if (shadow > EPSILON) {
                shadow *= GetShadowing(lightData);

                if (isEyeInWater != 1)
                    skyLight = max(skyLight, shadow);
            }

            #ifdef SHADOW_COLOR
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    if (lightData.shadowPos[lightData.transparentShadowCascade].z - lightData.transparentShadowDepth > lightData.shadowBias[lightData.transparentShadowCascade])
                        shadowColor = GetShadowColor(lightData.shadowPos[lightData.transparentShadowCascade].xy);
                #else
                    if (lightData.shadowPos.z - lightData.transparentShadowDepth > lightData.shadowBias)
                        shadowColor = GetShadowColor(lightData.shadowPos.xy);
                #endif
            #endif
        
            #ifdef SHADOW_CLOUD
                vec3 viewLightDir = normalize(shadowLightPosition);
                vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;
                //vec3 upDir = normalize(upPosition);

                float cloudF = GetCloudFactor(worldPos, localLightDir, 0);
                float horizonFogF = pow(1.0 - max(localLightDir.y, 0.0), 8.0);
                float cloudShadow = 1.0 - mix(cloudF, 1.0, horizonFogF);
                shadow *= cloudShadow;
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
    vec3 diffuse = albedo.rgb * pow3(lightData.blockLight) * blockLightColor;

    vec3 waterExtinctionInv = WATER_ABSROPTION_RATE * (1.0 - waterAbsorbColor);

    //vec3 skyAmbient = vec3(pow(skyLight, 5.0));
    #ifdef SKY_ENABLED
        #ifdef RENDER_WEATHER
            vec3 skyColorLux = RGBToLinear(skyColor);// * skyTint;
            //if (all(lessThan(skyColorLux, vec3(EPSILON)))) skyColorLux = vec3(1.0);
            //skyColorLux = normalize(skyColorLux);
            skyColorLux = 20000.0 * skyColorLux;
            ambient += skyColorLux * max(lightData.skyLightLevels.x, 0.0);// * skyLight * ShadowBrightnessF;
        #else
            #if ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
                vec3 localNormal = mat3(gbufferModelViewInverse) * viewNormal;
                ambient += GetFancySkyAmbientLight(localNormal, skyLight);
            #else
                ambient += GetSkyAmbientLight(lightData, worldPos.y, viewNormal) * skyLight * ShadowBrightnessF;
            #endif

            vec3 sunColorFinal = lightData.sunTransmittance * sunColor;// * GetSunLux();
            vec3 moonColorFinal = lightData.moonTransmittance * moonColor * GetMoonPhaseLevel();// * GetMoonLux();
            vec3 skyLightColor = 0.2 * (sunColorFinal + moonColorFinal);

            if (isEyeInWater == 1) {
                vec3 sunAbsorption = exp(-max(lightData.waterShadowDepth, 0.0) * waterExtinctionInv);

                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    if (lightData.opaqueShadowDepth < lightData.shadowPos[lightData.shadowCascade].z - lightData.shadowBias[lightData.shadowCascade])
                        sunAbsorption = 1.0 - (1.0 - sunAbsorption) * (1.0 - ShadowBrightnessF);
                #else
                    if (lightData.opaqueShadowDepth < lightData.shadowPos.z - lightData.shadowBias)
                        sunAbsorption = 1.0 - (1.0 - sunAbsorption) * (1.0 - ShadowBrightnessF);
                #endif

                ambient *= sunAbsorption;
                skyLightColor *= sunAbsorption;
            }

            diffuse += albedo.rgb * lightData.geoNoL * skyLightColor * shadowColor * shadow;
        #endif
    #endif

    #if defined HANDLIGHT_ENABLED && !defined RENDER_HAND && !defined RENDER_HAND_WATER
        if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
            //const float roughL = 1.0;
            //const float scattering = 0.0;
            diffuse += ApplyHandLighting(albedo.rgb, viewPos.xyz);
        }
    #endif

    vec4 final = albedo;
    final.rgb *= ambient;
    final.rgb += diffuse;

    float viewDist = length(viewPos);
    vec3 viewDir = viewPos / viewDist;

    #ifdef SKY_ENABLED
        vec3 sunColorFinalEye = lightData.sunTransmittanceEye * sunColor;
        vec3 moonColorFinalEye = lightData.moonTransmittanceEye * moonColor * GetMoonPhaseLevel();

        #ifdef RENDER_WEATHER
            vec3 sunDir = normalize(sunPosition);
            float sun_VoL = dot(viewDir, sunDir);
            float rainSnowSunVL = mix(
                ComputeVolumetricScattering(sun_VoL, -0.16),
                ComputeVolumetricScattering(sun_VoL, 0.66),
                0.3);

            vec3 moonDir = normalize(moonPosition);
            float moon_VoL = dot(viewDir, moonDir);
            float rainSnowMoonVL = mix(
                ComputeVolumetricScattering(moon_VoL, -0.16),
                ComputeVolumetricScattering(moon_VoL, 0.66),
                0.3);

            vec3 weatherLightColor = 6.0 * 
                max(rainSnowSunVL, 0.0) * sunColorFinalEye +
                max(rainSnowMoonVL, 0.0) * moonColorFinalEye;

            //float alpha = mix(WEATHER_OPACITY * 0.01, 1.0, saturate(max(rainSnowSunVL, rainSnowMoonVL)));

            final.rgb += albedo.rgb * weatherLightColor;// * shadow;
            final.a = albedo.a * rainStrength * (WEATHER_OPACITY * 0.01);
        #else
            if (isEyeInWater == 1) {
                vec3 viewAbsorption = exp(-viewDist * waterExtinctionInv);
                final.rgb *= viewAbsorption;
            }
        #endif
    #endif

    #ifdef WATER_ENABLED
        if (isEyeInWater == 1) {
            #ifdef SKY_ENABLED
                vec3 waterSunColorEye = sunColorFinalEye * max(lightData.skyLightLevels.x, 0.0);
                vec3 waterMoonColorEye = moonColorFinalEye * max(lightData.skyLightLevels.y, 0.0);
                vec2 waterScatteringF = GetWaterScattering(viewDir);

                vec3 waterFogColor = GetWaterFogColor(waterSunColorEye, waterMoonColorEye, waterScatteringF);
            #else
                vec3 waterFogColor = vec3(0.0);
            #endif

            ApplyWaterFog(final.rgb, waterFogColor, viewDist);

            #if defined SKY_ENABLED && defined SHADOW_ENABLED && defined VL_WATER_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                vec3 nearViewPos = viewDir * near;
                vec3 farViewPos = viewDir * min(viewDist, waterFogDistSmooth);

                final.rgb += GetWaterVolumetricLighting(lightData, nearViewPos, farViewPos, waterScatteringF);
            #endif
        }
        else {
    #endif

        #if !defined SKY_ENABLED || !defined VL_SKY_ENABLED
            final.rgb *= exp(-ATMOS_EXTINCTION * viewDist);
        #endif

        float fogFactor;
        vec3 fogColorFinal;
        GetFog(lightData, worldPos, viewPos, fogColorFinal, fogFactor);

        #ifdef SKY_ENABLED
            vec3 localViewDir = normalize(localPos);

            vec2 scatteringF = GetVanillaSkyScattering(viewDir, skyLightLevels);

            #if defined VL_SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                vec3 viewNear = viewDir * near;
                vec3 vlExt = vec3(1.0);

                vec3 vlColor = GetVolumetricLighting(lightData, vlExt, viewNear, viewPos, scatteringF);

                final.rgb *= vlExt;
            #else
                vec3 lightColor = scatteringF.x * sunColorFinalEye + scatteringF.y * moonColorFinalEye;
                fogColorFinal += lightColor * RGBToLinear(fogColor);
            #endif
        #endif

        ApplyFog(final, fogColorFinal, fogFactor, 1.0/255.0);

        #ifdef SKY_ENABLED
            float cloudDepthTest = CLOUD_LEVEL - worldPos.y;
            cloudDepthTest *= sign(CLOUD_LEVEL - cameraPosition.y);

            if (HasClouds(cameraPosition, localViewDir) && cloudDepthTest < 0.0) {
                vec3 cloudPos = GetCloudPosition(cameraPosition, localViewDir);
                float cloudF = GetCloudFactor(cloudPos, localViewDir, 0);

                float cloudHorizonFogF = 1.0 - abs(localViewDir.y);
                cloudF *= 1.0 - pow(cloudHorizonFogF, 8.0);

                // vec3 sunDir = GetSunDir();
                // float sun_VoL = dot(viewDir, sunDir);

                // vec3 moonDir = GetMoonDir();
                // float moon_VoL = dot(viewDir, moonDir);

                vec3 cloudColor = GetCloudColor(cloudPos, viewDir, skyLightLevels);

                //cloudF = smoothstep(0.0, 1.0, cloudF);
                //final.rgb = mix(final.rgb, cloudColor, cloudF);
                // TODO: mix opacity?
            }

            #if defined VL_SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                final.rgb += vlColor;

                // TODO: vl alter alpha?
            #endif
        #endif

    #ifdef WATER_ENABLED
        }
    #endif

    return final;
}
