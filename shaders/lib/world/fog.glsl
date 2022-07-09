float GetFogFactor(const in float viewDist, const in float start, const in float end, const in float density) {
    float distFactor = min(max(viewDist - start, 0.0) / (end - start), 1.0);
    return pow(distFactor, density);
}

float GetCaveFogFactor(const in float viewDist) {
    float end = min(60.0, fogEnd);
    return GetFogFactor(viewDist, 0.0, end, 1.0);
}

float GetCustomFogFactor(const in float viewDist) {
    const float dayFogDensity = 2.5;
    const float nightFogDensity = 1.2;
    const float rainFogDensity = 0.36;

    float sunLightIntensity = GetSkyLightIntensity().x;

    float density = mix(nightFogDensity, dayFogDensity, sunLightIntensity);
    density = mix(density, rainFogDensity, rainStrength);

    float strength = mix(0.4, 1.0, rainStrength);

    return GetFogFactor(viewDist, 0.0, fogEnd, density) * strength;
}

float GetVanillaFogFactor(const in float viewDist) {
    //vec3 fogPos = viewPos;
    //if (fogShape == 1) fogPos.z = 0.0;
    return GetFogFactor(viewDist, fogStart, fogEnd, 1.0);
}

float ApplyFog(inout vec3 color, const in vec3 viewPos, const in float skyLightLevel) {
    #ifdef SHADOW_ENABLED
        vec3 viewDir = normalize(viewPos);
        vec3 atmosphereColor = GetSkyColor(viewDir);
    #else
        vec3 atmosphereColor = RGBToLinear(fogColor);
    #endif

    float viewDist = length(viewPos) - near;
    float maxFactor = 0.0;

    #ifdef CAVEFOG_ENABLED
        float caveLightFactor = min(6.0 * skyLightLevel, 1.0);
        vec3 caveFogColor = mix(vec3(0.002), atmosphereColor, caveLightFactor);

        float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
        float cameraLightFactor = min(6.0 * eyeBrightness, 1.0);
    #endif

    float customFogFactor = GetCustomFogFactor(viewDist);
    maxFactor = max(maxFactor, customFogFactor);

    float vanillaFogFactor = GetVanillaFogFactor(viewDist);
    maxFactor = max(maxFactor, vanillaFogFactor);

    #ifdef CAVEFOG_ENABLED
        float caveFogFactor = GetCaveFogFactor(viewDist);
        caveFogFactor *= 1.0 - caveLightFactor;
        //caveFogFactor *= 1.0 - cameraLightFactor * vanillaFogFactor;
        maxFactor = max(maxFactor, caveFogFactor);
    #endif

    color = mix(color, atmosphereColor, customFogFactor);
    color = mix(color, atmosphereColor, vanillaFogFactor);

    #ifdef CAVEFOG_ENABLED
        color = mix(color, caveFogColor, caveFogFactor);
    #endif

    return maxFactor;
}

void ApplyFog(inout vec4 color, const in vec3 viewPos, const in float skyLightLevel, const in float alphaTestRef) {
    float fogFactor = ApplyFog(color.rgb, viewPos, skyLightLevel);

    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogFactor);
}
