vec4 GetFancyFog(const in vec3 localPos, const in vec3 localSunDir, const in float VoL) {
    const float atmosScale = (atmosphereRadiusMM - groundRadiusMM) / (ATMOSPHERE_LEVEL - SEA_LEVEL);

    vec3 atmosPos = GetAtmospherePosition(cameraPosition + localPos);
    float sampleElevation = length(atmosPos) - groundRadiusMM;

    //vec3 viewDir = normalize(farViewPos - nearViewPos);
    //float VoL = dot(viewLightDir, viewDir);
    float miePhaseValue = getMiePhase(VoL);
    float rayleighPhaseValue = getRayleighPhase(-VoL);

    float mieScattering;
    vec3 rayleighScattering, extinction;
    getScatteringValues(atmosPos, rayleighScattering, mieScattering, extinction);

    float texDensity = mix(1.6, 2.8, rainStrength);
    float dt = length(localPos) * atmosScale * texDensity;
    vec3 sampleTransmittance = exp(-dt*extinction);

    vec3 sunColorSky = SunLux * GetSunColor();
    vec3 moonColorSky = MoonLux * GetMoonColor();

    #if SHADER_PLATFORM == PLATFORM_IRIS
        vec3 sunTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.x) * sunColorSky;
        vec3 moonTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.y) * moonColorSky;
    #else
        vec3 sunTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.x) * sunColorSky;
        vec3 moonTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.y) * moonColorSky;
    #endif

    vec3 lightTransmittance = sunTransmittance + moonTransmittance;

    #if SHADER_PLATFORM == PLATFORM_IRIS
        vec3 psiMS = getValFromMultiScattLUT(texMultipleScattering, atmosPos, localSunDir) * SKY_FANCY_LUM;
    #else
        vec3 psiMS = getValFromMultiScattLUT(colortex13, atmosPos, localSunDir) * SKY_FANCY_LUM;
    #endif

    vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * lightTransmittance + psiMS);
    vec3 mieInScattering = mieScattering * (miePhaseValue * lightTransmittance + psiMS);
    vec3 inScattering = (rayleighInScattering + mieInScattering);

    // Integrated scattering within path segment.
    vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

    return vec4(scatteringIntegral, sampleTransmittance);
}
