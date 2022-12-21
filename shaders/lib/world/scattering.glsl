float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    float G_scattering2 = pow2(G_scattering);

    return rcp(4.0 * PI) * ((1.0 - G_scattering2) / (pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5)));
}

float GetScatteringFactor(const in float sunLightLevel) {
    if (isEyeInWater == 1) return G_SCATTERING_WATER;

    float scattering = mix(G_SCATTERING_NIGHT, G_SCATTERING_CLEAR, sunLightLevel);

    //scattering = mix(scattering, G_SCATTERING_HUMID, pow2(eyeHumidity));

    scattering = mix(scattering, G_SCATTERING_RAIN, pow2(wetness)); // rainStrength

    return scattering;
}

vec2 GetVanillaSkyScattering(const in vec3 viewDir, const in vec2 skyLightLevels) {
    float sunLightLevel = saturate(skyLightLevels.x);
    float scattering_G = GetScatteringFactor(sunLightLevel);
    vec2 scatteringF;

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        vec3 sunDir = GetFixedSunPosition();
    #else
        vec3 sunDir = normalize(sunPosition);
    #endif

    float sun_VoL = dot(viewDir, sunDir);
    scatteringF.x = mix(
        ComputeVolumetricScattering(sun_VoL, -0.2),
        ComputeVolumetricScattering(sun_VoL, 0.86),
        0.4);

    vec3 moonDir = normalize(moonPosition);
    float moon_VoL = dot(viewDir, moonDir);
    scatteringF.y = mix(
        ComputeVolumetricScattering(moon_VoL, -0.2),
        ComputeVolumetricScattering(moon_VoL, 0.86),
        0.4);

    //scatteringF *= 1.0 + 1.0 * wetness;

    return max(scatteringF, vec2(0.0)) * (0.01 * VL_STRENGTH);
}
