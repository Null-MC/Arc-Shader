#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    float GetAverageLuminance_EyeBrightness(const in vec2 eyeBrightness, const in float skyLightLux) {
        float blockLightBrightness = eyeBrightness.x;

        #ifdef HANDLIGHT_ENABLED
            blockLightBrightness = max(blockLightBrightness, heldBlockLightValue * 0.0625);
        #endif

        blockLightBrightness = blockLightBrightness*blockLightBrightness * BlockLightLux;
        float skyLightBrightness = eyeBrightness.y * skyLightLux;
        return 0.1 * max(blockLightBrightness, skyLightBrightness);
    }
#elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
    float GetAverageLuminance_Mipmap(const in int lod) {
        //int minMip = textureQueryLevels(BUFFER_LUMINANCE) - 1;
        float averageLuminance = textureLod(BUFFER_HDR_PREVIOUS, vec2(0.5), lod).a;
        return exp(averageLuminance);
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

    //float lumMax = 9.6 * avgLumClamped;

    const float S = 100.0;
    const float K = 12.5;
    return log2(avgLumClamped * S / K);
}

float GetExposure(const in float EV100) {
    //return 1.0 / exp2(EV100 - 3.0);
    float maxLum = 1.2 * exp2(EV100);
    return 1.0 / maxLum;
}


// Auto

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
    int GetLuminanceLod() {
        return textureQueryLevels(BUFFER_HDR_PREVIOUS)-1;
    }
#endif

float GetAverageLuminance() {
    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
            vec2 skyLightLevels = GetSkyLightLevels();
            float sunLightLux = GetSunLightLevel(skyLightLevels.x) * SunLux;
            float moonLightLux = GetMoonLightLevel(skyLightLevels.y) * MoonLux;

            vec2 eyeBrightness = eyeBrightnessSmooth / 240.0;
            return GetAverageLuminance_EyeBrightness(eyeBrightness, sunLightLux + moonLightLux);
        #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            int luminanceLod = GetLuminanceLod();
            return GetAverageLuminance_Mipmap(luminanceLod);
        #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_HISTOGRAM
            return GetAverageLuminance_Histogram();
        #else
            return 0.0;
        #endif
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
