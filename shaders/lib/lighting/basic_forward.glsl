vec4 BasicLighting(const in LightData lightData, const in vec4 albedo) {
    float shadow = step(EPSILON, lightData.geoNoL);
    //shadow *= step(1.0 / 32.0, lightData.skyLight);

    float skyLight = lightData.skyLight;
    vec3 shadowColor = vec3(1.0);

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

                float cloudF = GetCloudFactor(cameraPosition + localPos, localLightDir);
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
    vec3 diffuse = albedo.rgb * pow5(lightData.blockLight) * blockLightColor;

    //vec3 skyAmbient = vec3(pow(skyLight, 5.0));
    #ifdef SKY_ENABLED
        float ambientBrightness = mix(0.8 * skyLight2, 0.95 * skyLight, rainStrength) * SHADOW_BRIGHTNESS;
        ambient += GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;

        #ifndef RENDER_WEATHER
            vec3 sunColorFinal = lightData.sunTransmittance * sunColor;// * GetSunLux();
            vec3 moonColorFinal = lightData.moonTransmittance * moonColor * GetMoonPhaseLevel();// * GetMoonLux();
            vec3 skyLightColor = sunColorFinal + moonColorFinal;
            diffuse += albedo.rgb * skyLightColor * shadowColor * shadow *skyLight3;
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
        vec3 sunColorFinalEye = lightData.sunTransmittanceEye * sunColor;
        vec3 moonColorFinalEye = lightData.moonTransmittanceEye * moonColor * GetMoonPhaseLevel();
    #endif

    #ifdef RENDER_WEATHER
        vec3 sunDir = normalize(sunPosition);
        float sun_VoL = dot(viewDir, sunDir);
        float rainSnowSunVL = ComputeVolumetricScattering(sun_VoL, 0.88);

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        float rainSnowMoonVL = ComputeVolumetricScattering(moon_VoL, 0.74);

        vec3 weatherLightColor = 3.0 * (
            max(rainSnowSunVL, 0.0) * sunColorFinalEye +
            max(rainSnowMoonVL, 0.0) * moonColorFinalEye);

        final.rgb += albedo.rgb * weatherLightColor * shadow;
        final.a = albedo.a * rainStrength * mix(WEATHER_OPACITY * 0.01, 1.0, saturate(max(rainSnowSunVL, rainSnowMoonVL)));
    #endif

    float fogFactor;
    vec3 fogColorFinal;
    GetFog(lightData, viewPos, fogColorFinal, fogFactor);

    #ifdef SKY_ENABLED
        vec2 scatteringF = GetVanillaSkyScattering(viewDir, skyLightLevels);

        #ifndef VL_ENABLED
            vec3 lightColor = scatteringF.x * sunColorFinalEye + scatteringF.y * moonColorFinalEye;
            fogColorFinal += lightColor * RGBToLinear(fogColor);
        #endif
    #endif

    ApplyFog(final, fogColorFinal, fogFactor, 1.0/255.0);

    #if defined SKY_ENABLED && defined VL_ENABLED
        vec3 viewNear = viewDir * near;

        final.rgb += GetVolumetricLighting(lightData, viewNear, viewPos, scatteringF);
    #endif

    return final;
}
