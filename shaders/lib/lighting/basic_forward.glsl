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
                skyLight = max(skyLight, shadow);
            }

            #ifdef SHADOW_COLOR
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    shadowColor = GetShadowColor(lightData);
                #else
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

    //vec3 skyAmbient = vec3(pow(skyLight, 5.0));
    #ifdef SKY_ENABLED
        float ambientBrightness = mix(0.8 * skyLight2, 0.95 * skyLight, rainStrength) * SHADOW_BRIGHTNESS;
        ambient += GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;

        #ifndef RENDER_WEATHER
            vec3 sunColorFinal = lightData.sunTransmittance * sunColor * max(lightData.skyLightLevels.x, 0.0);// * GetSunLux();
            vec3 moonColorFinal = lightData.moonTransmittance * moonColor * max(lightData.skyLightLevels.y, 0.0) * GetMoonPhaseLevel();// * GetMoonLux();
            vec3 skyLightColor = sunColorFinal + moonColorFinal;
            diffuse += albedo.rgb * lightData.geoNoL * skyLightColor * shadowColor * shadow * skyLight3;
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

    vec3 viewDir = normalize(viewPos);

    #ifdef SKY_ENABLED
        vec3 sunColorFinalEye = lightData.sunTransmittanceEye * sunColor * max(lightData.skyLightLevels.x, 0.0);
        vec3 moonColorFinalEye = lightData.moonTransmittanceEye * moonColor * GetMoonPhaseLevel() * max(lightData.skyLightLevels.y, 0.0);
    #endif

    #ifdef RENDER_WEATHER
        vec3 sunDir = normalize(sunPosition);
        float sun_VoL = dot(viewDir, sunDir);
        float rainSnowSunVL = mix(
            ComputeVolumetricScattering(sun_VoL, -0.6),
            ComputeVolumetricScattering(sun_VoL, 0.86),
            0.1);

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        float rainSnowMoonVL = mix(
            ComputeVolumetricScattering(moon_VoL, -0.6),
            ComputeVolumetricScattering(moon_VoL, 0.86),
            0.1);

        vec3 weatherLightColor = 3.0 * 
            max(rainSnowSunVL, 0.0) * sunColorFinalEye +
            max(rainSnowMoonVL, 0.0) * moonColorFinalEye;

        //float alpha = mix(WEATHER_OPACITY * 0.01, 1.0, saturate(max(rainSnowSunVL, rainSnowMoonVL)));

        final.rgb += albedo.rgb * weatherLightColor * shadow;
        final.a = albedo.a * rainStrength * (WEATHER_OPACITY * 0.01);
    #endif

    if (isEyeInWater != 1) {
        #if !defined SKY_ENABLED || !defined VL_SKY_ENABLED
            float viewDist = length(viewPos);
            final.rgb *= exp(-ATMOS_EXTINCTION * viewDist);
        #endif

        float fogFactor;
        vec3 fogColorFinal;
        GetFog(lightData, viewPos, fogColorFinal, fogFactor);

        #ifdef SKY_ENABLED
            vec3 localViewDir = normalize(localPos);

            vec2 scatteringF = GetVanillaSkyScattering(viewDir, skyLightLevels);

            #ifdef VL_SKY_ENABLED
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

            if (cloudDepthTest < 0.0) {
                float cloudF = GetCloudFactor(cameraPosition, localViewDir, 0);

                float cloudHorizonFogF = 1.0 - abs(localViewDir.y);
                cloudF *= 1.0 - pow(cloudHorizonFogF, 8.0);

                vec3 cloudColor = GetCloudColor(skyLightLevels);

                cloudF = smoothstep(0.0, 1.0, cloudF);
                //final.rgb = mix(final.rgb, cloudColor, cloudF);
                // TODO: mix opacity?
            }

            #ifdef VL_SKY_ENABLED
                final.rgb += vlColor;

                // TODO: vl alter alpha?
            #endif
        #endif
    }

    return final;
}
