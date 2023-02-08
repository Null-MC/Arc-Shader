float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    float G_scattering2 = pow2(G_scattering);

    return rcp(4.0 * PI) * ((1.0 - G_scattering2) / (pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5)));
}

vec2 GetWaterScattering(const in vec3 viewDir) {
    #ifdef SKY_ENABLED
        vec2 scatteringF;

        vec3 sunViewDir = GetSunViewDir();
        float sun_VoL = dot(viewDir, sunViewDir);
        scatteringF.x = mix(
            ComputeVolumetricScattering(sun_VoL, -0.2),
            ComputeVolumetricScattering(sun_VoL, 0.8),
            0.7);

        vec3 moonViewDir = GetMoonViewDir();
        float moon_VoL = dot(viewDir, moonViewDir);
        scatteringF.y = mix(
            ComputeVolumetricScattering(moon_VoL, -0.2),
            ComputeVolumetricScattering(moon_VoL, 0.8),
            0.7);

        return max(scatteringF, vec2(0.0));
    #else
        return vec2(0.0);
    #endif
}
