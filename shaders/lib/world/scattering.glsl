float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    float G_scattering2 = pow2(G_scattering);

    return rcp(4.0 * PI) * ((1.0 - G_scattering2) / (pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5)));
}

vec2 GetWaterScattering(const in float sun_VoL, const in float moon_VoL) {
    vec2 scatteringF;

    scatteringF.x = mix(
        ComputeVolumetricScattering(sun_VoL, -0.2),
        ComputeVolumetricScattering(sun_VoL, 0.8),
        0.7);

    scatteringF.y = mix(
        ComputeVolumetricScattering(moon_VoL, -0.2),
        ComputeVolumetricScattering(moon_VoL, 0.8),
        0.7);

    return max(scatteringF, vec2(0.0));
}

vec2 GetWaterScattering(const in vec3 viewDir) {
    #ifdef SKY_ENABLED
        vec3 sunViewDir = GetSunViewDir();
        float sun_VoL = dot(viewDir, sunViewDir);

        vec3 moonViewDir = GetMoonViewDir();
        float moon_VoL = dot(viewDir, moonViewDir);

        return GetWaterScattering(sun_VoL, moon_VoL);
    #else
        return vec2(0.0);
    #endif
}
