float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    float G_scattering2 = G_scattering * G_scattering;

    return (1.0 - G_scattering2) / max(4.0 * PI * pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5), 0.1);
}

float GetScatteringFactor(const in float sunLightLevel) {
    if (isEyeInWater == 1) return G_SCATTERING_WATER;

    float scattering = mix(G_SCATTERING_NIGHT, G_SCATTERING_CLEAR, sunLightLevel);

    #ifdef IS_OPTIFINE
        scattering = mix(scattering, G_SCATTERING_HUMID, eyeHumidity);
    #endif

    scattering = mix(scattering, G_SCATTERING_RAIN, wetness); // rainStrength

    //scattering = min(scattering + G_SCATTERING_NIGHT, 1.0);

    return scattering;
}

vec3 GetVanillaSkyScattering(const in vec3 viewDir, const in float sunLightLevel, const in vec3 sunColor, const in vec3 moonColor) {
    float scattering = GetScatteringFactor(sunLightLevel);

    float scatterDistF = far - near;
    if (isEyeInWater == 1) {
        //scatterDistF /= 1.0;
    }
    else {
        scatterDistF /= 101.0 - VL_STRENGTH;
    }

    scatterDistF = min(scatterDistF, 1.0);

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

    vec3 vlColor = (sunScattering * sunColor + moonScattering * moonColor) * scatterDistF;

    if (isEyeInWater == 1) vlColor *= vec3(0.1, 0.7, 1.0);

    return vlColor;
}
