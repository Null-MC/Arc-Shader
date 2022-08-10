#ifdef SHADOW_COLOR
    vec3 GetVolumetricColor(const in PbrLightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / VL_SAMPLE_COUNT;
        vec3 accumCol = vec3(0.0);

        #ifdef VL_DITHER
            const mat4 DITHER_PATTERN = mat4(
                vec4(0.0f, 0.5f, 0.125f, 0.625f),
                vec4(0.75f, 0.22f, 0.875f, 0.375f),
                vec4(0.1875f, 0.6875f, 0.0625f, 0.5625f),
                vec4(0.9375f, 0.4375f, 0.8125f, 0.3125f));

            int ditherX = int(gl_FragCoord.x * viewWidth) % 4;
            int ditherY = int(gl_FragCoord.y * viewHeight) % 4;
            vec3 ditherOffset = rayDirection * stepLength * DITHER_PATTERN[ditherX][ditherY];
        #endif

        for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;

            #ifdef VL_DITHER
                currentShadowViewPos += ditherOffset;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                for (int i = 0; i < 4; i++) {
                    shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;

                    vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                    shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;
                }

                // WARN: The lightData.geoNoL is only for the current pixel, not the VL sample!
                const float geoNoL = 1.0; //lightData.geoNoL;
                float depthSample = CompareNearestDepth(shadowPos, vec2(0.0), geoNoL);

                if (depthSample > EPSILON) {
                    vec3 shadowColor = GetShadowColor(shadowPos, geoNoL);
                    accumCol += RGBToLinear(shadowColor) * depthSample;
                }
            #else
                vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    shadowPos.xyz = distort(shadowPos.xyz);
                #endif

                shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

                // WARN: The lightData.shadowBias is only for the current pixel, not the VL sample!
                const float shadowBias = 0.0; //lightData.shadowBias;
                float depthSample = CompareDepth(shadowPos, vec2(0.0), shadowBias);

                if (depthSample > EPSILON) {
                    vec3 shadowColor = GetShadowColor(shadowPos.xyz, -shadowBias);
                    accumCol += RGBToLinear(shadowColor) * depthSample;
                }
            #endif
        }

        return accumCol / VL_SAMPLE_COUNT;
    }
#else
    float GetVolumetricFactor(const in PbrLightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / VL_SAMPLE_COUNT;
        float accumF = 0.0;

        for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                for (int i = 0; i < 4; i++) {
                    shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;

                    vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                    shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;
                }

                // WARN: The lightData.geoNoL is only for the current pixel, not the VL sample!
                const float geoNoL = 1.0; //lightData.geoNoL;
                accumF += CompareNearestDepth(shadowPos, vec2(0.0), geoNoL);
            #else
                vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    shadowPos.xyz = distort(shadowPos.xyz);
                #endif

                shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

                // WARN: The lightData.shadowBias is only for the current pixel, not the VL sample!
                const float shadowBias = 0.0; //lightData.shadowBias;
                accumF += CompareDepth(shadowPos, vec2(0.0), shadowBias);
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
