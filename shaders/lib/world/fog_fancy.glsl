vec3 GetFancyFog(const in vec3 localPos, out vec3 transmittance) {
    const float isotropicPhase = 0.25 / PI;
    const float texDensity = 1.0;

    vec3 SkyAbsorptionCoefficient = vec3(mix(0.0024, 0.0020, rainStrength));
    vec3 SkyScatteringCoefficient = vec3(mix(0.0008, 0.0020, rainStrength));
    vec3 SkyExtinctionCoefficient = SkyScatteringCoefficient + SkyAbsorptionCoefficient;

    vec3 localSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);

    float viewDist = length(localPos);
    transmittance = exp(-SkyExtinctionCoefficient * viewDist * texDensity);

    vec3 scatteringIntegral = (1.0 - transmittance) / SkyExtinctionCoefficient;

    vec3 atmosPos = localPos - vec3(0.0, SEA_LEVEL + cameraPosition.y, 0.0);
    atmosPos *= (atmosphereRadiusMM - groundRadiusMM) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
    atmosPos.y = groundRadiusMM + clamp(atmosPos.y, 0.0, atmosphereRadiusMM - groundRadiusMM);

    #if SHADER_PLATFORM == PLATFORM_IRIS
        vec3 scatterColor = getValFromMultiScattLUT(texMultipleScattering, atmosPos, localSunDir) * 5.5e6;
    #else
        vec3 scatterColor = getValFromMultiScattLUT(colortex12, atmosPos, localSunDir) * 5.5e6;
    #endif

    return scatterColor * (isotropicPhase * SkyScatteringCoefficient * scatteringIntegral);// * transmittance;
}