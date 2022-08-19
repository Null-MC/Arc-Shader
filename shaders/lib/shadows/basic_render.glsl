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
        vec3 GetShadowColor(const in PbrLightData lightData) {
            // TODO: enable HW-comp on Iris
            float waterDepth = textureLod(shadowtex0, lightData.shadowPos.xy, 0).r;
            if (lightData.shadowPos.z - lightData.shadowBias < waterDepth) return vec3(1.0);

            return textureLod(shadowcolor0, lightData.shadowPos.xy, 0).rgb;
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
        float GetShadowing_PCF(const in PbrLightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
            #ifdef SHADOW_DITHER
                float dither = 0.5 + 0.5*GetScreenBayerValue();
            #endif

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = poissonDisk[i] * pixelRadius;

                #ifdef SHADOW_DITHER
                    pixelOffset *= dither;
                #endif
                
                shadow += 1.0 - CompareDepth(lightData.shadowPos, pixelOffset, lightData.shadowBias);
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

        float GetShadowing(const in PbrLightData lightData) {
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, SHADOW_PCF_SIZE);

            // blocker search
            int blockerSampleCount = POISSON_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
            float blockerDistance = FindBlockerDistance(lightData.shadowPos, pixelRadius, blockerSampleCount);
            if (blockerDistance <= 0.0) return 1.0;
            //if (blockerDistance == 1.0) return 0.0;

            // penumbra estimation
            float penumbraWidth = (lightData.shadowPos.z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            pixelRadius *= min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = POISSON_SAMPLES;
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
            return 1.0 - GetShadowing_PCF(lightData, pixelRadius, pcfSampleCount);
        }
    #elif SHADOW_FILTER == 1
        // PCF
        float GetShadowing(const in PbrLightData lightData) {
            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, SHADOW_PCF_SIZE);
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            //float biasMax = shadowBias * (max(pixelRadius.x, pixelRadius.y) / shadowPixelSize);
            return 1.0 - GetShadowing_PCF(lightData, pixelRadius, sampleCount);
        }
    #elif SHADOW_FILTER == 0
        // Unfiltered
        float GetShadowing(const in PbrLightData lightData) {
            #ifdef SHADOW_ENABLE_HWCOMP
                return CompareDepth(lightData.shadowPos, vec2(0.0), lightData.shadowBias);
            #else
                float texDepth = SampleDepth(lightData.shadowPos, vec2(0.0));
                return step(lightData.shadowPos.z - EPSILON, texDepth + lightData.shadowBias);
            #endif
        }
    #endif

    #if defined SSS_ENABLED
        float SampleShadowSSS(const in vec2 shadowPos) {
            uint data = textureLod(shadowcolor1, shadowPos, 0).g;
            return unpackUnorm4x8(data).a;
        }

        #ifdef SSS_SCATTER
            float GetShadowing_PCF_SSS(const in PbrLightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
                #ifdef SSS_DITHER
                    float dither = 0.5 + 0.5*GetScreenBayerValue();
                #endif

                float light = 0.0;
                float sampleHit = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;

                    #ifdef SSS_DITHER
                        pixelOffset *= dither;
                    #endif

                    float texDepth = SampleDepth(lightData.shadowPos, pixelOffset);
                    //light += step(shadowPos.z + shadowBias, texDepth + 0.001);

                    if (texDepth < lightData.shadowPos.z + lightData.shadowBias) {
                        float shadow_sss = SampleShadowSSS(lightData.shadowPos.xy + pixelOffset);
                        shadow_sss = sqrt(max(shadow_sss, EPSILON));

                        float dist = max(lightData.shadowPos.z + lightData.shadowBias - texDepth, 0.0) * 2.0 * far;
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

        #ifdef SSS_SCATTER
            // PCF + PCSS
            float GetShadowSSS(const in PbrLightData lightData, out float traceDist) {
                float texDepth = SampleDepth(lightData.shadowPos, vec2(0.0));
                traceDist = max(lightData.shadowPos.z + lightData.shadowBias - texDepth, 0.0) * 2.0 * far;
                float distF = saturate(traceDist / SSS_MAXDIST);

                int sampleCount = SSS_PCF_SAMPLES;
                vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, SSS_PCF_SIZE * distF);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(lightData, pixelRadius, sampleCount);
            }
        #else
            // Unfiltered
            float GetShadowSSS(const in PbrLightData lightData, out float traceDist) {
                float texDepth = SampleDepth(lightData.shadowPos, vec2(0.0));
                traceDist = max(lightData.shadowPos.z + lightData.shadowBias - texDepth, 0.0) * 2.0 * far;

                float shadow_sss = SampleShadowSSS(lightData.shadowPos.xy);
                shadow_sss = sqrt(max(shadow_sss, EPSILON));
                return max(shadow_sss - traceDist / SSS_MAXDIST, 0.0);
            }
        #endif
    #endif
#endif
