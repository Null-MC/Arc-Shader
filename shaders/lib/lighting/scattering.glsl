#define VL_G_SCATTERING 0.9

float ComputeVolumetricScattering(const in float VoL) {
    const float G_scattering2 = VL_G_SCATTERING * VL_G_SCATTERING;

    return (1.0 - G_scattering2) / (4.0 * PI * pow(1.0 + G_scattering2 - (2.0 * VL_G_SCATTERING) * VoL, 1.5));
}
