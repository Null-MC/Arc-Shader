float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    float G_scattering2 = pow2(G_scattering);

    return rcp(4.0 * PI) * ((1.0 - G_scattering2) / (pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5)));
}

vec2 GetWaterScattering(const in vec3 viewDir) {
    #ifdef SKY_ENABLED
        vec2 scatteringF;

        #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
            vec3 sunDir = GetFixedSunPosition();
        #else
            vec3 sunDir = normalize(sunPosition);
        #endif

        float sun_VoL = dot(viewDir, sunDir);
        scatteringF.x = mix(
            ComputeVolumetricScattering(sun_VoL, -0.2),
            ComputeVolumetricScattering(sun_VoL, 0.6),
            0.7);

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        scatteringF.y = mix(
            ComputeVolumetricScattering(moon_VoL, -0.2),
            ComputeVolumetricScattering(moon_VoL, 0.6),
            0.7);

        return max(scatteringF, vec2(0.0));
    #else
        return vec2(0.0);
    #endif
}
