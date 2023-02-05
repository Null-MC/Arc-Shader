#ifdef RENDER_FRAG
    float SampleOpaqueDepth(const in vec2 shadowPos, const in vec2 offset) {
        return textureLod(shadowtex1, shadowPos + offset, 0).r;
    }

    float SampleTransparentDepth(const in vec2 shadowPos, const in vec2 offset) {
        return textureLod(shadowtex0, shadowPos + offset, 0).r;
    }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareOpaqueDepth(const in vec3 shadowPos, const in vec2 offset, const in float shadowBias) {
        #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
            return textureLod(shadowtex1HW, shadowPos + vec3(offset, -shadowBias), 0);
        #else
            float shadowDepth = textureLod(shadowtex1, shadowPos.xy + offset, 0).r;
            return step(shadowPos.z + EPSILON, shadowDepth + shadowBias);
        #endif
    }

    #ifdef SHADOW_COLOR
        vec3 GetShadowColor(const in vec2 shadowPos) {
            vec3 color = textureLod(shadowcolor0, shadowPos, 0).rgb;
            //color = RGBToLinear(color);
            return color;
        }
    #endif

    vec2 GetShadowPixelRadius(const in vec2 shadowPos, const in float blockRadius) {
        vec2 shadowProjectionSize = 2.0 / vec2(shadowProjection[0].x, shadowProjection[1].y);

        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            float distortFactor = getDistortFactor(shadowPos * 2.0 - 1.0);
            float maxRes = shadowMapSize / SHADOW_DISTORT_FACTOR;

            vec2 pixelPerBlockScale = maxRes / shadowProjectionSize;
            return blockRadius * pixelPerBlockScale * shadowPixelSize * (1.0 - distortFactor);
        #else
            vec2 pixelPerBlockScale = shadowMapSize / shadowProjectionSize;
            return blockRadius * pixelPerBlockScale * shadowPixelSize;
        #endif
    }

    #if SHADOW_FILTER != 0
        // PCF
        float GetShadowing_PCF(const in LightData lightData, const in vec2 pixelRadius, float bias) {
            #ifdef IRIS_FEATURE_SSBO
                float dither = InterleavedGradientNoise(gl_FragCoord.xy);
                float angle = fract(dither) * TAU;
                float s = sin(angle), c = cos(angle);
                mat2 rotation = mat2(c, -s, s, c);
            #else
                float startAngle = hash12(gl_FragCoord.xy) * TAU;
                vec2 rotation = vec2(cos(startAngle), sin(startAngle));

                const float angleDiff = -TAU / SHADOW_PCF_SAMPLES;
                const vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
                const mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);
            #endif

            float shadow = 0.0;
            for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
                #ifdef IRIS_FEATURE_SSBO
                    vec2 pixelOffset = (rotation * pcfDiskOffset[i]) * pixelRadius;
                #else
                    rotation *= rotationStep;
                    float noiseDist = hash13(vec3(gl_FragCoord.xy, i));
                    vec2 pixelOffset = rotation * noiseDist * pixelRadius;
                #endif
                
                shadow += 1.0 - CompareOpaqueDepth(lightData.shadowPos, pixelOffset, bias);
            }

            return 1.0 - shadow * rcp(SHADOW_PCF_SAMPLES);
        }
    #endif

    #if SHADOW_FILTER == 2
        // PCF + PCSS
        float FindBlockerDistance(const in LightData lightData, const in vec2 pixelRadius) {
            #ifdef IRIS_FEATURE_SSBO
                float dither = InterleavedGradientNoise(gl_FragCoord.xy);
                float angle = fract(dither) * TAU;
                float s = sin(angle), c = cos(angle);
                mat2 rotation = mat2(c, -s, s, c);
            #else
                float startAngle = hash12(gl_FragCoord.xy + 33.3) * TAU;
                vec2 rotation = vec2(cos(startAngle), sin(startAngle));

                const float angleDiff = -TAU / SHADOW_PCSS_SAMPLES;
                const vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
                const mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);
            #endif

            float blockers = 0.0;
            float avgBlockerDistance = 0.0;
            for (int i = 0; i < SHADOW_PCSS_SAMPLES; i++) {
                #ifdef IRIS_FEATURE_SSBO
                    vec2 pixelOffset = (rotation * pcssDiskOffset[i]) * pixelRadius;
                #else
                    rotation *= rotationStep;
                    float noiseDist = hash13(vec3(gl_FragCoord.xy, i + 33.3));
                    vec2 pixelOffset = rotation * noiseDist * pixelRadius;
                #endif

                vec2 t = lightData.shadowPos.xy + pixelOffset;
                if (saturate(t) != t) continue;

                float texDepth = SampleOpaqueDepth(lightData.shadowPos.xy, pixelOffset);

                float hitDist = max((lightData.shadowPos.z - lightData.shadowBias) - texDepth, 0.0);

                avgBlockerDistance += hitDist * (far * 2.0);
                blockers += step(0.0, hitDist);
            }

            return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
        }

        float GetShadowing(const in LightData lightData) {
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, shadowPcfSize);
            float bias = lightData.shadowBias;

            // blocker search
            float blockerDistance = FindBlockerDistance(lightData, pixelRadius);
            if (blockerDistance <= 0.0) return 1.0;

            //bias += blockerDistance;

            pixelRadius *= min(blockerDistance * SHADOW_PENUMBRA_SCALE, 1.0);
            return GetShadowing_PCF(lightData, pixelRadius, bias);
        }
    #elif SHADOW_FILTER == 1
        // PCF
        float GetShadowing(const in LightData lightData) {
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, shadowPcfSize);
            return GetShadowing_PCF(lightData, pixelRadius, lightData.shadowBias);
        }
    #elif SHADOW_FILTER == 0
        // Unfiltered
        float GetShadowing(const in LightData lightData) {
            #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
                return textureLod(shadowtex1HW, lightData.shadowPos + vec3(offset, -lightData.shadowBias), 0);
            #else
                float surfaceDepth = lightData.shadowPos.z - lightData.shadowBias;
                float texDepth = lightData.opaqueShadowDepth + EPSILON;
                return step(surfaceDepth, texDepth);
            #endif
        }
    #endif

    #if defined SSS_ENABLED
        float GetShadowing_PCF_SSS(const in LightData lightData, const in vec2 pixelRadius) {
            #ifdef IRIS_FEATURE_SSBO
                float dither = InterleavedGradientNoise(gl_FragCoord.xy);
                float angle = fract(dither) * TAU;
                float s = sin(angle), c = cos(angle);
                mat2 rotation = mat2(c, -s, s, c);
            #else
                float startAngle = hash12(gl_FragCoord.xy + 33.3) * TAU;
                vec2 rotation = vec2(cos(startAngle), sin(startAngle));

                const float angleDiff = -TAU / SSS_PCF_SAMPLES;
                const vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
                const mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);
            #endif

            float light = 0.0;
            for (int i = 0; i < SSS_PCF_SAMPLES; i++) {
                #ifdef IRIS_FEATURE_SSBO
                    vec2 pixelOffset = (rotation * sssDiskOffset[i]) * pixelRadius;
                #else
                    rotation *= rotationStep;
                    float noiseDist = hash13(vec3(gl_FragCoord.xy, i + 33.3));
                    vec2 pixelOffset = rotation * noiseDist * pixelRadius;
                #endif

                float texDepth = SampleOpaqueDepth(lightData.shadowPos.xy, pixelOffset);

                float hitDepth = max(texDepth - (lightData.shadowPos.z - lightData.shadowBias), 0.0);
                light += max(1.0 - hitDepth, 0.0);
            }

            return light * rcp(SSS_PCF_SAMPLES);
        }

        // PCF + PCSS
        float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float lightDist) {
            lightDist = max(lightData.shadowPos.z - lightData.shadowBias - lightData.opaqueShadowDepth, 0.0) * (far * 2.0);
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, SSS_PCF_SIZE * lightDist);

            float sss = GetShadowing_PCF_SSS(lightData, pixelRadius);
            return max(sss * materialSSS - lightDist / SSS_MAXDIST, 0.0);
        }
    #endif
#endif
