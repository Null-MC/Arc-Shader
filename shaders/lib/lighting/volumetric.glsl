#ifdef SHADOW_COLOR
    vec3 GetVolumetricColor(PbrLightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / VL_SAMPLE_COUNT;
        vec3 rayStep = rayDirection * stepLength;
        vec3 accumCol = vec3(0.0);

        #ifdef VL_DITHER
            vec3 ditherOffset = rayStep * GetScreenBayerValue();
        #endif

        for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayStep;

            #ifdef VL_DITHER
                currentShadowViewPos += ditherOffset;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                //vec3 shadowPos[4];
                for (int i = 0; i < 4; i++) {
                    lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;

                    vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                    lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + shadowCascadePos;
                }

                // WARN: The lightData.geoNoL is only for the current pixel, not the VL sample!
                //const float geoNoL = 1.0; //lightData.geoNoL;
                float depthSample = CompareNearestDepth(lightData, vec2(0.0));
            #else
                lightData.shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz);
                #endif

                lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;

                // WARN: The lightData.shadowBias is only for the current pixel, not the VL sample!
                lightData.shadowBias = 0.0;

                float depthSample = CompareDepth(lightData.shadowPos, vec2(0.0), lightData.shadowBias);
            #endif

            if (depthSample > EPSILON) {
                vec3 shadowColor = GetShadowColor(lightData);
                accumCol += RGBToLinear(shadowColor) * depthSample;
            }
        }

        return accumCol / VL_SAMPLE_COUNT;
    }
#else
    float GetVolumetricFactor(PbrLightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / VL_SAMPLE_COUNT;
        float accumF = 0.0;

        #ifdef VL_DITHER
            vec3 ditherOffset = rayDirection * stepLength * GetScreenBayerValue();
        #endif

        for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;

            #ifdef VL_DITHER
                currentShadowViewPos += ditherOffset;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                //vec3 shadowPos[4];
                for (int i = 0; i < 4; i++) {
                    lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;

                    //vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                    lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
                }

                // WARN: The lightData.geoNoL is only for the current pixel, not the VL sample!
                //const float geoNoL = 1.0; //lightData.geoNoL;
                accumF += CompareNearestDepth(lightData, vec2(0.0));
            #else
                lightData.shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz);
                #endif

                lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;

                // WARN: The lightData.shadowBias is only for the current pixel, not the VL sample!
                lightData.shadowBias = 0.0;

                accumF += CompareDepth(lightData, vec2(0.0));
            #endif
        }

        return accumF / VL_SAMPLE_COUNT;
    }
#endif

#ifdef SHADOW_COLOR
    float _GetShadowLightScattering(const in vec3 ray, const in float G_scattering) {
        const vec3 sunDir = vec3(0.0, 0.0, 1.0);
        float VoL = dot(normalize(ray), sunDir);

        float rayLen = min(length(ray) / (101.0 - VL_STRENGTH), 1.0);
        return ComputeVolumetricScattering(VoL, G_scattering) * rayLen;
    }

    vec3 GetVolumetricLightingColor(const in PbrLightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float G_scattering) {
        vec3 ray = shadowViewEnd - shadowViewStart;
        float scattering = _GetShadowLightScattering(ray, G_scattering);
        if (scattering < EPSILON) return vec3(0.0);

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            return GetVolumetricColor(lightData, shadowViewStart, shadowViewEnd) * scattering;
        #else
            return GetVolumetricColor(lightData, shadowViewStart, shadowViewEnd) * scattering;
        #endif
    }
#else
    float GetVolumetricLighting(const in PbrLightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float G_scattering) {
        vec3 ray = shadowViewEnd - shadowViewStart;
        float scattering = _GetShadowLightScattering(ray, G_scattering);
        if (scattering < EPSILON) return 0.0;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            return GetVolumetricFactor(lightData, shadowViewStart, shadowViewEnd) * scattering;
        #else
            return GetVolumetricFactor(lightData, shadowViewStart, shadowViewEnd) * scattering;
        #endif
    }
#endif
