#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    float GetEyeBrightnessLuminance() {
        vec2 eyeBrightnessLinear = eyeBrightness / 240.0;

        vec2 skyLightLevels = GetSkyLightLevels();
        float sunLightLux = GetSunLightLevel(skyLightLevels.x) * SunLux;
        float moonLightLux = GetMoonLightLevel(skyLightLevels.y) * MoonLux;
        float skyLightBrightness = pow(eyeBrightnessLinear.y, 5.0) * (sunLightLux + moonLightLux);

        float blockLightBrightness = eyeBrightnessLinear.x;

        #ifdef HANDLIGHT_ENABLED
            blockLightBrightness = max(blockLightBrightness, heldBlockLightValue * 0.0625);
        #endif

        blockLightBrightness = pow(blockLightBrightness, 5.0) * BlockLightLux;

        return max(blockLightBrightness, skyLightBrightness);
    }
#endif

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
    float maxLum = (2.0 - screenBrightness) * exp2(EV100);
    return 1.0 / maxLum;
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
        ivec2 size = ivec2(ceil(vec2(viewWidth, viewHeight) / exp2(luminanceLod)));
        size = min(size, ivec2(12, 8));

        for (int y = 0; y < size.y; y++) {
            for (int x = 0; x < size.x; x++) {
                float sampleLum = texelFetch(BUFFER_HDR_PREVIOUS, ivec2(x, y), luminanceLod).a;
                sampleLum = max(exp2(sampleLum) - EPSILON, 0.0);

                averageLuminance += sampleLum;
                //averageLuminance = max(averageLuminance, sampleLum);
            }
        }

        averageLuminance /= size.x*size.y;
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
    float EV100 = GetEV100();
    return GetExposure(EV100 - CAMERA_EXPOSURE + 2.0);
}
