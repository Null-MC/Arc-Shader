float GetFogFactor(const in float viewDist, const in float start, const in float end, const in float density) {
    float distFactor = min(max(viewDist - start, 0.0) / (end - start), 1.0);
    return pow(distFactor, density);
}

float GetCaveFogFactor(const in float viewDist) {
    float end = min(60.0, fogEnd);
    return GetFogFactor(viewDist, 0.0, end, 1.0);
}

float GetCustomFogFactor(const in float viewDist, const in float sunLightLevel) {
    const float dayFogDensity = 1.5;
    const float nightFogDensity = 1.0;
    const float rainFogDensity = 0.75;

    const float dayFogStrength = 0.3;
    const float nightFogStrength = 0.5;
    const float rainFogStrength = 1.0;

    float density = mix(nightFogDensity, dayFogDensity, sunLightLevel);
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
    #ifdef SKY_ENABLED
        vec3 viewDir = normalize(viewPos);
        vec3 atmosphereColor = GetVanillaSkyLuminance(viewDir);

        // #ifdef RENDER_FALSE
        //     float G_scattering = mix(G_SCATTERING_CLEAR, G_SCATTERING_RAIN, rainStrength);

        //     vec3 sunDir = normalize(sunPosition);
        //     float sun_VoL = dot(viewDir, sunDir);
        //     float sunScattering = ComputeVolumetricScattering(sun_VoL, G_scattering);
        //     atmosphereColor += sunScattering * sunColor;

        //     vec3 moonDir = normalize(moonPosition);
        //     float moon_VoL = dot(viewDir, moonDir);
        //     float moonScattering = ComputeVolumetricScattering(moon_VoL, G_scattering);
        //     atmosphereColor += moonScattering * moonColor;
        // #endif
    #else
        vec3 atmosphereColor = RGBToLinear(fogColor) * 100.0;
    #endif

    float viewDist = length(viewPos) - near;
    float maxFactor = 0.0;

    float caveLightFactor = min(6.0 * skyLightLevel, 1.0);
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

    #ifdef ATMOSFOG_ENABLED
        vec2 skyLightLevels = GetSkyLightLevels();
        float sunLightLevel = GetSunLightLevel(skyLightLevels.x);

        float customFogFactor = GetCustomFogFactor(viewDist, sunLightLevel);
    #endif

    float vanillaFogFactor = GetVanillaFogFactor(viewDist);
    maxFactor = max(maxFactor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        float caveFogFactor = GetCaveFogFactor(viewDist);
        caveFogFactor *= 1.0 - caveLightFactor;
        //caveFogFactor *= 1.0 - cameraLightFactor * vanillaFogFactor;
        maxFactor = max(maxFactor, caveFogFactor);
    #endif

    #ifdef ATMOSFOG_ENABLED
        // TODO: reduce cave-fog-factor with distance
        customFogFactor *= caveLightFactor;

        maxFactor = max(maxFactor, customFogFactor);
        color = mix(color, atmosphereColor, customFogFactor);
    #endif

    color = mix(color, atmosphereColor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        color = mix(color, caveFogColorBlend, caveFogFactor);
    #endif

    return maxFactor;
}

void ApplyFog(inout vec4 color, const in vec3 viewPos, const in float skyLightLevel, const in float alphaTestRef) {
    float fogFactor = ApplyFog(color.rgb, viewPos, skyLightLevel);

    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogFactor);
}
