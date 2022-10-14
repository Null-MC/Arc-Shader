float GetEV100(const in float lum, const in float S, const in float K) {
    return log2(lum * S / K);
}

float GetEV100(const in float avgLum) {
    const float S = 100.0;
    const float K = 12.5;
    return GetEV100(avgLum, S, K);
}

float GetExposureKeyValue(const in float avgLum) {
    return 1.03 - 2.0 / (2.0 + log(avgLum + 1.0));
}

float GetExposure(const in float EV100) {
    float brightnessF = 1.0;//3.0 - 2.0*screenBrightness;

    #if MC_VERSION >= 11900
        brightnessF *= 1.0 - 0.9*darknessFactor;
    #endif

    return rcp(brightnessF * exp2(EV100));
}

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    int GetLuminanceLod() {
        return textureQueryLevels(BUFFER_HDR_PREVIOUS)-1;
    }
#endif

float GetAverageLuminance() {
    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        float lum = texelFetch(BUFFER_HDR_PREVIOUS, ivec2(0), 0).a;
        float avgLum = max(exp2(lum) - EPSILON, 0.0);
    #elif CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        int luminanceLod = GetLuminanceLod();

        float averageLuminance = 0.0;
        // vec2 texSize = SSR_SCALE * vec2(viewWidth, viewHeight);

        // ivec2 lodSize = ivec2(ceil(texSize / exp2(luminanceLod)));
        // lodSize = min(lodSize, ivec2(12, 8));

        // for (int y = 0; y < lodSize.y; y++) {
        //     for (int x = 0; x < lodSize.x; x++) {
        //         //float sampleLum = texelFetch(BUFFER_HDR_PREVIOUS, ivec2(x, y), luminanceLod).a;
        //         float sampleLum = textureLod(BUFFER_HDR_PREVIOUS, vec2(x, y) / lodSize, luminanceLod).a;
        //         sampleLum = max(exp2(sampleLum) - EPSILON, 0.0);
        //         averageLuminance += sampleLum;
        //     }
        // }

        float sampleLum = texelFetch(BUFFER_HDR_PREVIOUS, ivec2(0), luminanceLod).a;
        float avgLum = max(exp2(sampleLum) - EPSILON, 0.0);

        //return averageLuminance / (lodSize.x*lodSize.y);
    #else
        float avgLum = 0.0;
    #endif

    return clamp(avgLum, CAMERA_LUM_MIN, CAMERA_LUM_MAX);
}

float GetExposure() {
    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        float avgLum = GetAverageLuminance();

        //float keyValue = GetExposureKeyValue(avgLum);
        float EV100 = GetEV100(avgLum);// - keyValue;
    #else
        float EV100 = 0.0;
    #endif

    return GetExposure(EV100 - CAMERA_EXPOSURE);
}
