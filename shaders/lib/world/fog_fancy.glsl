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

    const float texDensity = 1.0;//mix(1.0, 2.8, rainStrength);
    float dt = length(localPos) * atmosScale * texDensity;
    vec3 sampleTransmittance = exp(-dt*extinction);

    vec3 sunColorSky = SunLux * GetSunColor();

    vec3 sunTransmittance = GetTransmittance(sampleElevation, skyLightLevels.x) * sunColorSky;

    vec3 lightTransmittance = sunTransmittance;

    #ifdef WORLD_MOON_ENABLED
        vec3 moonColorSky = MoonLux * GetMoonColor();

        vec3 moonTransmittance = GetTransmittance(sampleElevation, skyLightLevels.y) * moonColorSky;

        lightTransmittance += moonTransmittance;
    #endif

    vec3 psiMS = getValFromMultiScattLUT(atmosPos, localSunDir) * SKY_FANCY_LUM;

    //psiMS *= 0.4;
    float eyeLight = eyeBrightnessSmooth.y / 240.0;
    //lightTransmittance *= eyeLight;
    //psiMS *= eyeLight;

    vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * lightTransmittance + psiMS);
    vec3 mieInScattering = mieScattering * (miePhaseValue * lightTransmittance + psiMS);
    vec3 inScattering = (rayleighInScattering + mieInScattering) * eyeLight;

    // Integrated scattering within path segment.
    vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

    return vec4(scatteringIntegral, sampleTransmittance);
}
