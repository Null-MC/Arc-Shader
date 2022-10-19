float GetFogFactor(const in float viewDist, const in float start, const in float end, const in float density) {
    float distFactor = min(max(viewDist - start, 0.0) / (end - start), 1.0);
    return saturate(pow(distFactor, density));
}

float GetCaveFogFactor(const in float viewDist) {
    float end = min(60.0, fogEnd);
    return GetFogFactor(viewDist, 0.0, end, 1.0);
}

#ifdef SKY_ENABLED
    float GetCustomFogFactor(const in float viewDist, const in float sunLightLevel) {
        const float dayFogDensity = 1.5;
        const float nightFogDensity = 1.2;
        const float rainFogDensity = 1.0;

        const float dayFogStrength = 0.2;
        const float nightFogStrength = 0.3;
        const float rainFogStrength = 0.8;

        float density = mix(nightFogDensity, dayFogDensity, saturate(sunLightLevel));
        float strength = mix(nightFogStrength, dayFogStrength, saturate(sunLightLevel));

        // #ifdef IS_OPTIFINE
        //     //density = mix(density, rainFogDensity, rainStrength);
        //     density = max(density - 0.2 * eyeHumidity, 0.0);
        //     strength = min(strength + 0.4 * eyeHumidity, 1.0);
        // #endif

        density = mix(density, rainFogDensity, rainStrength);
        strength = mix(strength, rainFogStrength, rainStrength);

        return saturate(GetFogFactor(viewDist, 0.0, fogEnd, density) * strength);
    }
#endif

float GetVanillaFogFactor(const in float viewDist) {
    //vec3 fogPos = viewPos;
    //if (fogShape == 1) fogPos.z = 0.0;
    return GetFogFactor(viewDist, fogStart, fogEnd, 1.0);
}

float ApplyFog(inout vec3 color, const in vec3 viewPos, const in LightData lightData) {
    #ifdef SKY_ENABLED
        vec3 viewDir = normalize(viewPos);
        vec3 atmosphereColor = GetVanillaSkyLuminance(viewDir);
        //vec2 skyLightLevels = GetSkyLightLevels();
    #else
        vec3 atmosphereColor = RGBToLinear(fogColor) * 100.0;
    #endif

    #if MC_VERSION >= 11900
        atmosphereColor *= 1.0 - darknessFactor;
    #endif

    float viewDist = length(viewPos);// - near;
    float maxFactor = 0.0;

    float caveLightFactor = saturate(2.0 * lightData.skyLight);
    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        vec3 caveFogColor = 0.001 * RGBToLinear(vec3(0.3294, 0.1961, 0.6588));
        vec3 caveFogColorBlend = mix(caveFogColor, atmosphereColor, caveLightFactor);

        float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
        float cameraLightFactor = min(6.0 * eyeBrightness, 1.0);
    #endif

    // #ifdef RENDER_DEFERRED
    //     atmosphereColor *= exposure;
    //     caveFogColor *= exposure;
    // #endif

    #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
        float sunLightLevel = GetSunLightLevel(lightData.skyLightLevels.x);

        float customFogFactor = GetCustomFogFactor(viewDist, sunLightLevel);
    #endif

    float vanillaFogFactor = GetVanillaFogFactor(viewDist);
    maxFactor = max(maxFactor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        float caveFogFactor = GetCaveFogFactor(viewDist);

        #ifdef LIGHTLEAK_FIX
            caveFogFactor *= 1.0 - caveLightFactor;
            //caveFogFactor *= 1.0 - cameraLightFactor * vanillaFogFactor;
        #endif

        maxFactor = max(maxFactor, caveFogFactor);
    #endif

    #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
        #ifdef LIGHTLEAK_FIX
            // TODO: reduce cave-fog-factor with distance
            customFogFactor *= caveLightFactor;
        #endif

        maxFactor = max(maxFactor, customFogFactor);
        color = mix(color, atmosphereColor, customFogFactor);
    #endif

    color = mix(color, atmosphereColor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        color = mix(color, caveFogColorBlend, caveFogFactor);
    #endif

    #if defined SKY_ENABLED && !defined VL_ENABLED
        vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux();// * sunColor
        color += maxFactor * GetVanillaSkyScattering(viewDir, lightData.skyLightLevels, sunColorFinal, moonColor);
    #endif

    return maxFactor;
}

void ApplyFog(inout vec4 color, const in vec3 viewPos, const in LightData lightData, const in float alphaTestRef) {
    float fogFactor = ApplyFog(color.rgb, viewPos, lightData);

    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogFactor);
}
