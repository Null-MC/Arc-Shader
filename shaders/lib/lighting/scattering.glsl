float ComputeVolumetricScattering(const in float VoL, const in float G_scattering) {
    const float G_scattering2 = G_scattering * G_scattering;

    return (1.0 - G_scattering2) / (4.0 * PI * pow(1.0 + G_scattering2 - (2.0 * G_scattering) * VoL, 1.5));
}
