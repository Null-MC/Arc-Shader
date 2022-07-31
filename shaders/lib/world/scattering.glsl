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
