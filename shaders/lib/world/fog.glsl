const vec3 caveFogColor = vec3(0.02);


float GetFogFactor(const in float viewDist, const in float start, const in float end, const in float strength) {
    float distFactor = min(max(viewDist - start, 0.0) / (end - start), 1.0);
    return pow(distFactor, strength);
}

float GetCaveFogFactor(const in float viewDist) {
    float end = min(40.0, fogEnd);
    return GetFogFactor(viewDist, 2.0, end, 1.0);
}

float GetCustomFogFactor(const in float viewDist) {
    float near = mix(8.0, 0.0, rainStrength);
    float strength = mix(3.0, 0.36, rainStrength);
    return GetFogFactor(viewDist, near, fogEnd, strength);
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

    float viewDist = length(viewPos);
    float maxFactor = 0.0;

    float caveFactor = min(4.0 * skyLightLevel, 1.0);
    vec3 caveFogColor = mix(vec3(0.002), atmosphereColor, caveFactor);

    float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
    float cameraCaveFactor = min(4.0 * eyeBrightness, 1.0);

    float customFogFactor = GetCustomFogFactor(viewDist);
    maxFactor = max(maxFactor, customFogFactor);

    float vanillaFogFactor = GetVanillaFogFactor(viewDist);
    maxFactor = max(maxFactor, vanillaFogFactor);

    float caveFogFactor = GetCaveFogFactor(viewDist);
    caveFogFactor *= 1.0 - caveFactor;
    caveFogFactor *= 1.0 - cameraCaveFactor * vanillaFogFactor;
    maxFactor = max(maxFactor, caveFogFactor);

    color = mix(color, caveFogColor, caveFogFactor);
    color = mix(color, atmosphereColor, customFogFactor);
    color = mix(color, atmosphereColor, vanillaFogFactor);

    return maxFactor;
}

void ApplyFog(inout vec4 color, const in vec3 viewPos, const in float skyLightLevel, const in float alphaTestRef) {
    float fogFactor = ApplyFog(color.rgb, viewPos, skyLightLevel);

    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogFactor);
}
