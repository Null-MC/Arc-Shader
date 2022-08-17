#ifdef RENDER_VERTEX
    void ApplyShadows(const in vec3 shadowViewPos, const in vec3 viewDir) {}
#endif

#ifdef RENDER_FRAG
    float SampleDepth(const in vec4 shadowPos, const in vec2 offset) {
        #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
            return textureLod(shadowtex1, shadowPos.xy + offset * shadowPos.w, 0).r;
        #elif defined SHADOW_ENABLE_HWCOMP
            return textureLod(shadowtex0, shadowPos.xy + offset * shadowPos.w, 0).r;
        #else
            return textureLod(shadowtex1, shadowPos.xy + offset * shadowPos.w, 0).r;
        #endif
    }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareDepth(const in vec4 shadowPos, const in vec2 offset, const in float shadowBias) {
        #ifdef SHADOW_ENABLE_HWCOMP
            #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                return textureLod(shadowtex1HW, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0);
            #else
                return textureLod(shadowtex1, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0);
            #endif
        #else
            float shadowDepth = textureLod(shadowtex1, shadowPos.xy + offset * shadowPos.w, 0).r;
            return step(shadowPos.z + EPSILON, shadowDepth + shadowBias);
        #endif
    }

    #ifdef SHADOW_COLOR
        vec3 GetShadowColor(const in vec3 shadowPos, const in float shadowBias) {
            // TODO: enable HW-comp on Iris
            float waterDepth = textureLod(shadowtex0, shadowPos.xy, 0).r;
            if (shadowPos.z - shadowBias < waterDepth) return vec3(1.0);

            return textureLod(shadowcolor0, shadowPos.xy, 0).rgb;
        }
    #endif

    vec2 GetShadowPixelRadius(const in vec2 shadowPos, const in float blockRadius) {
        vec2 shadowProjectionSize = 2.0 / vec2(shadowProjection[0].x, shadowProjection[1].y);

        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            float distortFactor = getDistortFactor(shadowPos * 2.0 - 1.0);
            float maxRes = shadowMapSize / SHADOW_DISTORT_FACTOR;
            //float maxResPixel = 1.0 / maxRes;

            vec2 pixelPerBlockScale = maxRes / shadowProjectionSize;
            return blockRadius * pixelPerBlockScale * shadowPixelSize * (1.0 - distortFactor);
        #else
            vec2 pixelPerBlockScale = shadowMapSize / shadowProjectionSize;
            return blockRadius * pixelPerBlockScale * shadowPixelSize;
        #endif
    }

    #if SHADOW_FILTER != 0
        // PCF
        float GetShadowing_PCF(const in vec4 shadowPos, const in float shadowBias, const in vec2 pixelRadius, const in int sampleCount) {
            #ifdef SHADOW_DITHER
                vec2 ditherOffset = pixelRadius * GetScreenBayerValue();
            #endif

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = poissonDisk[i] * pixelRadius;

                #ifdef SHADOW_DITHER
                    pixelOffset += ditherOffset;
                #endif

                shadow += 1.0 - CompareDepth(shadowPos, pixelOffset, shadowBias);
            }

            return shadow / sampleCount;
        }
    #endif

    #if SHADOW_FILTER == 2
        // PCF + PCSS
        float FindBlockerDistance(const in vec4 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
            //float radius = SearchWidth(uvLightSize, shadowPos.z);
            //float radius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
            float avgBlockerDistance = 0.0;
            int blockers = 0;

            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = poissonDisk[i] * pixelRadius;
                float texDepth = SampleDepth(shadowPos, pixelOffset);

                if (texDepth < shadowPos.z) {
                    avgBlockerDistance += texDepth;
                    blockers++;
                }
            }

            if (blockers == sampleCount) return 1.0;
            return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
        }

        float GetShadowing(const in vec4 shadowPos, const in float shadowBias) {
            vec2 pixelRadius = GetShadowPixelRadius(shadowPos.xy, SHADOW_PCF_SIZE);

            // blocker search
            int blockerSampleCount = POISSON_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
            float blockerDistance = FindBlockerDistance(shadowPos, pixelRadius, blockerSampleCount);
            if (blockerDistance <= 0.0) return 1.0;
            //if (blockerDistance == 1.0) return 0.0;

            // penumbra estimation
            float penumbraWidth = (shadowPos.z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            pixelRadius *= min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = POISSON_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
            return 1.0 - GetShadowing_PCF(shadowPos, shadowBias, pixelRadius, pcfSampleCount);
        }
    #elif SHADOW_FILTER == 1
        // PCF
        float GetShadowing(const in vec4 shadowPos, const in float shadowBias) {
            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetShadowPixelRadius(shadowPos.xy, SHADOW_PCF_SIZE);
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            //float biasMax = shadowBias * (max(pixelRadius.x, pixelRadius.y) / shadowPixelSize);
            return 1.0 - GetShadowing_PCF(shadowPos, shadowBias, pixelRadius, sampleCount);
        }
    #elif SHADOW_FILTER == 0
        // Unfiltered
        float GetShadowing(const in vec4 shadowPos, const in float shadowBias) {
            #ifdef SHADOW_ENABLE_HWCOMP
                return CompareDepth(shadowPos, vec2(0.0), shadowBias);
            #else
                float texDepth = SampleDepth(shadowPos, vec2(0.0));
                return step(shadowPos.z - EPSILON, texDepth + shadowBias);
            #endif
        }
    #endif

    #if defined SSS_ENABLED
        float SampleShadowSSS(const in vec2 shadowPos) {
            uint data = textureLod(shadowcolor1, shadowPos, 0).g;
            return unpackUnorm4x8(data).a;
        }

        #if SSS_FILTER != 0
            float GetShadowing_PCF_SSS(const in vec4 shadowPos, const in float shadowBias, const in vec2 pixelRadius, const in int sampleCount) {
                #ifdef SSS_DITHER
                    vec2 ditherOffset = pixelRadius * GetScreenBayerValue();
                #endif

                float light = 0.0;
                float sampleHit = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;

                    #ifdef SSS_DITHER
                        pixelOffset += ditherOffset;
                    #endif

                    float texDepth = SampleDepth(shadowPos, pixelOffset);
                    //light += step(shadowPos.z + shadowBias, texDepth + 0.001);

                    if (texDepth < shadowPos.z + shadowBias) {
                        float shadow_sss = SampleShadowSSS(shadowPos.xy + pixelOffset);

                        float dist = max(shadowPos.z + shadowBias - texDepth, 0.0) * 2.0 * far;
                        light += max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                        //light++;
                        sampleHit++;
                    }
                    else {
                        light++;
                    }
                }

                return light / max(sampleHit, 1.0);
            }
        #endif

        #if SSS_FILTER == 2
            // PCF + PCSS
            float GetShadowSSS(const in vec4 shadowPos, const in float shadowBias) {
                float texDepth = SampleDepth(shadowPos, vec2(0.0));
                float dist = max(shadowPos.z + shadowBias - texDepth, 0.0) * 2.0 * far;
                float distF = 0.1 + saturate(dist / SSS_MAXDIST);

                int sampleCount = SSS_PCF_SAMPLES;
                vec2 pixelRadius = GetShadowPixelRadius(shadowPos.xy, SSS_PCF_SIZE * distF);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(shadowPos, shadowBias, pixelRadius, sampleCount);
            }
        #elif SSS_FILTER == 1
            // PCF
            float GetShadowSSS(const in vec4 shadowPos, const in float shadowBias) {
                int sampleCount = SSS_PCF_SAMPLES;
                vec2 pixelRadius = GetShadowPixelRadius(shadowPos.xy, SSS_PCF_SIZE);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(shadowPos, shadowBias, pixelRadius, sampleCount);
            }
        #elif SSS_FILTER == 0
            // Unfiltered
            float GetShadowSSS(const in vec4 shadowPos, const in float shadowBias) {
                float texDepth = SampleDepth(shadowPos, vec2(0.0));
                float dist = max(shadowPos.z - texDepth, 0.0) * 2.0 * far;

                float shadow_sss = SampleShadowSSS(shadowPos.xy);
                return max(shadow_sss - dist / SSS_MAXDIST, 0.0);
            }
        #endif
    #endif
#endif
