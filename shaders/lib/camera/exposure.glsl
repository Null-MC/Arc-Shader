#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    float GetAverageLuminance_EyeBrightness(const in vec2 eyeBrightness, const in vec2 skyLightIntensity) {
        float skyLightBrightness = eyeBrightness.y * max(skyLightIntensity.x, skyLightIntensity.y);
        return 0.008 + 0.5 * max(eyeBrightness.x, skyLightBrightness);
    }
#elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
    float GetAverageLuminance_Mipmap(const in int lod) {
        //int minMip = textureQueryLevels(BUFFER_LUMINANCE) - 1;
        float averageLuminance = textureLod(BUFFER_LUMINANCE, vec2(0.5), lod).r;
        return exp2(averageLuminance);
    }
#elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_HISTOGRAM
    float GetAverageLuminance_Histogram() {
        // TODO: Not Yet Implemented
        return 0.0;
    }
#endif

float GetEV100(const in float averageLuminance) {
    //return EXPOSURE_POINT / clamp(f, CAMERA_LUM_MIN, CAMERA_LUM_MAX);
    float avgLumClamped = clamp(averageLuminance, CAMERA_LUM_MIN, CAMERA_LUM_MAX);

    const float S = 500.0;
    const float K = 12.5;
    return log2(avgLumClamped * S / K);
}

float GetExposure(const in float EV100) {
    return 1.0 / exp2(EV100 - 3.0);
}
