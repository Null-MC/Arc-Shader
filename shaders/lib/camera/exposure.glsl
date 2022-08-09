float GetEV100(const in float averageLuminance) {
    //return EXPOSURE_POINT / clamp(f, CAMERA_LUM_MIN, CAMERA_LUM_MAX);
    float avgLumClamped = clamp(averageLuminance, CAMERA_LUM_MIN, CAMERA_LUM_MAX);

    //float lumMax = 9.6 * avgLumClamped;

    const float S = 100.0;
    const float K = 12.5;
    return log2(avgLumClamped * S / K);
}

float GetExposure(const in float EV100) {
    //return 1.0 / exp2(EV100 - 3.0);

    float brightnessF = 2.0 - screenBrightness;

    #if MC_VERSION >= 11900
        brightnessF *= 1.0 - 0.9*darknessFactor;
    #endif

    return rcp(brightnessF * exp2(EV100));
}


// Auto

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    int GetLuminanceLod() {
        return textureQueryLevels(BUFFER_HDR_PREVIOUS)-1;
    }
#endif

float GetAverageLuminance() {
    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        int luminanceLod = GetLuminanceLod()-2;

        float averageLuminance = 0.0;
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec2 texSize = 0.5 * viewSize;

        ivec2 lodSize = ivec2(ceil(texSize / exp2(luminanceLod)));
        lodSize = min(lodSize, ivec2(12, 8));

        for (int y = 0; y < lodSize.y; y++) {
            for (int x = 0; x < lodSize.x; x++) {
                float sampleLum = texelFetch(BUFFER_HDR_PREVIOUS, ivec2(x, y), luminanceLod).a;
                sampleLum = max(exp2(sampleLum) - EPSILON, 0.0);

                averageLuminance += sampleLum;
                //averageLuminance = max(averageLuminance, sampleLum);
            }
        }

        averageLuminance /= lodSize.x*lodSize.y;
        //averageLuminance = textureLod(BUFFER_HDR_PREVIOUS, vec2(0.5), luminanceLod).a;
        //return exp2(averageLuminance);
        return averageLuminance;
    #else
        return 0.0;
    #endif
}

float GetEV100() {
    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        float averageLuminance = GetAverageLuminance();
        return GetEV100(averageLuminance);
    #else
        return 0.0;
    #endif
}

float GetExposure() {
    float EV100 = GetEV100() - CAMERA_EXPOSURE;

    //EV100 += 8.0 * blindness;

    return GetExposure(EV100);
}
