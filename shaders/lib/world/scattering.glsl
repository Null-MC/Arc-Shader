float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    const float G_scattering2 = G_scattering * G_scattering;

    return (1.0 - G_scattering2) / max(4.0 * PI * pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5), 0.1);
}

float GetScatteringFactor() {
    float scattering = G_SCATTERING_CLEAR;

    #ifdef IS_OPTIFINE
        scattering = mix(scattering, G_SCATTERING_HUMID, eyeHumidity);
    #endif

    scattering = mix(scattering, G_SCATTERING_RAIN, rainStrength);
    
    return scattering;
}

vec3 GetVanillaSkyScattering(const in vec3 viewDir, const in vec3 sunColor, const in vec3 moonColor) {
    float scattering = GetScatteringFactor();
    float scatterDistF = min((far - near) / (101.0 - VL_STRENGTH), 1.0);

    #if defined IS_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED)
        vec3 sunLightDir = GetFixedSunPosition();
    #else
        vec3 sunLightDir = normalize(sunPosition);
    #endif

    float sun_VoL = dot(viewDir, sunLightDir);
    float sunScattering = ComputeVolumetricScattering(sun_VoL, scattering);

    vec3 moonLightDir = normalize(moonPosition);
    float moon_VoL = dot(viewDir, moonLightDir);
    float moonScattering = ComputeVolumetricScattering(moon_VoL, scattering);

    return (sunScattering * sunColor + moonScattering * moonColor) * scatterDistF;
}
