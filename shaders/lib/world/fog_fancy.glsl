vec3 GetFancyFog(const in vec3 localPos, out vec3 transmittance) {
    const float isotropicPhase = 0.25 / PI;
    const float texDensity = 0.3;

    vec3 SkyAbsorptionCoefficient = vec3(mix(0.0024, 0.0020, rainStrength));
    vec3 SkyScatteringCoefficient = vec3(mix(0.0008, 0.0020, rainStrength));
    vec3 SkyExtinctionCoefficient = SkyScatteringCoefficient + SkyAbsorptionCoefficient;

    vec3 localSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);

    float viewDist = length(localPos);
    transmittance = exp(-SkyExtinctionCoefficient * viewDist * texDensity);

    vec3 scatteringIntegral = (1.0 - transmittance) / SkyExtinctionCoefficient;

    vec3 atmosPos = localPos + vec3(0.0, cameraPosition.y - SEA_LEVEL, 0.0);
    atmosPos /= ATMOSPHERE_LEVEL - SEA_LEVEL;
    atmosPos.y = clamp(atmosPos.y, 0.004, 0.996);
    atmosPos *= atmosphereRadiusMM - groundRadiusMM;
    atmosPos += vec3(0.0, groundRadiusMM, 0.0);

    //atmosPos.y = groundRadiusMM + clamp(atmosPos.y - groundRadiusMM, 0.0, atmosphereRadiusMM - groundRadiusMM);

    #if SHADER_PLATFORM == PLATFORM_IRIS
        vec3 scatterColor = getValFromMultiScattLUT(texMultipleScattering, atmosPos, localSunDir) * 5.5e6;
    #else
        vec3 scatterColor = getValFromMultiScattLUT(colortex13, atmosPos, localSunDir) * 5.5e6;
    #endif

    scatterColor *= 0.06 + 0.94 * (eyeBrightnessSmooth.y / 240.0);

    return scatterColor * (isotropicPhase * SkyScatteringCoefficient * scatteringIntegral);// * transmittance;
}