float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    float G_scattering2 = G_scattering * G_scattering;

    return (1.0 - G_scattering2) / (4.0 * PI * pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5));
}

float GetScatteringFactor(const in float sunLightLevel) {
    if (isEyeInWater == 1) return G_SCATTERING_WATER;

    float scattering = mix(G_SCATTERING_NIGHT, G_SCATTERING_CLEAR, sunLightLevel);

    //#ifdef IS_OPTIFINE
        scattering = mix(scattering, G_SCATTERING_HUMID, eyeHumidity);
    //#endif

    scattering = mix(scattering, G_SCATTERING_RAIN, wetness); // rainStrength

    //scattering = min(scattering + G_SCATTERING_NIGHT, 1.0);

    return scattering;
}

vec3 GetVanillaSkyScattering(const in vec3 viewDir, const in vec2 skyLightLevels, const in vec3 sunColor, const in vec3 moonColor) {
    //float scattering = GetScatteringFactor(sunLightLevel);
    //vec2 skyLightLevels = GetSkyLightLevels();
    float scattering_G = GetScatteringFactor(skyLightLevels.x);
    vec3 vlColor = vec3(0.0);

    #if defined IS_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED)
        vec3 sunDir = GetFixedSunPosition();
    #else
        vec3 sunDir = normalize(sunPosition);
    #endif

    //float sun_VoL = dot(viewDir, sunLightDir);
    //float sunScattering = ComputeVolumetricScattering(sun_VoL, scattering);

    //vec3 moonLightDir = normalize(moonPosition);
    //float moon_VoL = dot(viewDir, moonLightDir);
    //float moonScattering = ComputeVolumetricScattering(moon_VoL, scattering);

    //vec3 vlColor = (sunScattering * sunColor + moonScattering * moonColor);// * scatterDistF;

    //vec3 sunDir = normalize(sunPosition);
    float sun_VoL = dot(viewDir, sunDir);
    float sunScattering = ComputeVolumetricScattering(sun_VoL, scattering_G);
    vlColor += sunScattering * sunColor;

    vec3 moonDir = normalize(moonPosition);
    float moon_VoL = dot(viewDir, moonDir);
    float moonScattering = ComputeVolumetricScattering(moon_VoL, scattering_G);
    vlColor += moonScattering * moonColor;

    if (isEyeInWater == 1) vlColor *= WATER_COLOR.rgb;

    return vlColor * (0.01 * VL_STRENGTH);
}
