#ifdef RENDER_VERTEX
    void ApplyShadows(const in vec3 shadowViewPos, const in vec3 viewDir) {}
#endif

#ifdef RENDER_FRAG
    float SampleOpaqueDepth(const in vec4 shadowPos, const in vec2 offset) {
        return textureLod(shadowtex1, shadowPos.xy + offset * shadowPos.w, 0).r;
    }

    float SampleTransparentDepth(const in vec4 shadowPos, const in vec2 offset) {
        return textureLod(shadowtex0, shadowPos.xy + offset * shadowPos.w, 0).r;
    }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareOpaqueDepth(const in vec4 shadowPos, const in vec2 offset, const in float shadowBias) {
        #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
            return textureLod(shadowtex1HW, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0);
        #else
            float shadowDepth = textureLod(shadowtex1, shadowPos.xy + offset * shadowPos.w, 0).r;
            return step(shadowPos.z + EPSILON, shadowDepth + shadowBias);
        #endif
    }

    // float GetWaterShadowDepth(const in LightData lightData) {
    //     float waterTexDepth = textureLod(shadowtex0, lightData.shadowPos.xy, 0).r;
    //     float waterDepth = lightData.shadowPos.z - lightData.shadowBias - waterTexDepth;
    //     return waterDepth * 3.0 * far;
    // }

    #ifdef SHADOW_COLOR
        vec3 GetShadowColor(const in vec2 shadowPos) {
            //if (lightData.shadowPos.z - lightData.transparentShadowDepth < EPSILON) return vec3(1.0);

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
        float GetShadowing_PCF(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
            #ifdef SHADOW_DITHER
                float dither = 0.95 + 0.1*GetScreenBayerValue();
            #endif

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = poissonDisk[i] * pixelRadius;

                #ifdef SHADOW_DITHER
                    pixelOffset *= dither;
                #endif
                
                shadow += 1.0 - CompareOpaqueDepth(lightData.shadowPos, pixelOffset, lightData.shadowBias);
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
                float texDepth = SampleOpaqueDepth(shadowPos, pixelOffset);

                if (texDepth < shadowPos.z) {
                    avgBlockerDistance += texDepth;
                    blockers++;
                }
            }

            if (blockers == sampleCount) return 1.0;
            return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
        }

        float GetShadowing(const in LightData lightData) {
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
        float GetShadowing(const in LightData lightData) {
            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, SHADOW_PCF_SIZE);
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            //float biasMax = shadowBias * (max(pixelRadius.x, pixelRadius.y) / shadowPixelSize);
            return 1.0 - GetShadowing_PCF(lightData, pixelRadius, sampleCount);
        }
    #elif SHADOW_FILTER == 0
        // Unfiltered
        float GetShadowing(const in LightData lightData) {
            float surfaceDepth = lightData.shadowPos.z - lightData.shadowBias;
            float texDepth = lightData.opaqueShadowDepth + EPSILON;
            return step(surfaceDepth, texDepth);
        }
    #endif

    #if defined SSS_ENABLED
        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            const float ShadowMaxDepth = 512.0;
        #else
            const float ShadowMaxDepth = 256.0;
        #endif

        float SampleShadowSSS(const in vec2 shadowPos) {
            #ifdef SHADOW_COLOR
                uint data = textureLod(shadowcolor1, shadowPos, 0).g;
                return unpackUnorm4x8(data).a;
            #else
                return textureLod(shadowcolor0, shadowPos, 0).r;
            #endif
        }

        #ifdef SSS_SCATTER
            float GetShadowing_PCF_SSS(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount, const in float materialSSS) {
                //float maxDist = SSS_MAXDIST * materialSSS;

                #ifdef SSS_DITHER
                    float dither = shadowPixelSize * (GetScreenBayerValue() - 0.5);
                #endif

                float light = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;

                    //#ifdef SSS_DITHER
                    //    pixelOffset += dither;
                    //#endif

                    float texDepth = SampleOpaqueDepth(lightData.shadowPos, pixelOffset);

                    //if (texDepth < 1.0 - EPSILON)
                    //if (lightData.shadowPos.z - lightData.shadowBias >= texDepth + EPSILON) continue;

                    if (texDepth < lightData.shadowPos.z + lightData.shadowBias) {
                        float shadow_sss = SampleShadowSSS(lightData.shadowPos.xy + pixelOffset);

                        if (shadow_sss >= EPSILON) {
                            float maxDist = SSS_MAXDIST * shadow_sss;

                            float lightDist = max(lightData.shadowPos.z + lightData.shadowBias - texDepth, 0.0) * ShadowMaxDepth;
                            light += max(1.0 - lightDist / maxDist, 0.0);
                        }
                    }
                    else {
                        light++;
                    }
                }

                return materialSSS * (light / sampleCount);
            }
        #endif

        #ifdef SSS_SCATTER
            // PCF + PCSS
            float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float lightDist) {
                lightDist = max(lightData.shadowPos.z + lightData.shadowBias - lightData.opaqueShadowDepth, 0.0) * ShadowMaxDepth;

                //float blockRadius = SSS_PCF_SIZE * (0.5 + 0.5*saturate(traceDist / SSS_MAXDIST));
                float shadow_sss = SampleShadowSSS(lightData.shadowPos.xy);
                //float maxDist = SSS_MAXDIST;// * sqrt(materialSSS);

                int sampleCount = SSS_PCF_SAMPLES;
                float blockRadius = SSS_PCF_SIZE * lightDist;// * (1.0 - 0.8*shadow_sss);
                vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, blockRadius);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(lightData, pixelRadius, sampleCount, materialSSS);
            }
        #else
            // Unfiltered
            float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float lightDist) {
                lightDist = max(lightData.shadowPos.z + lightData.shadowBias - lightData.opaqueShadowDepth, 0.0) * ShadowMaxDepth;

                return SampleShadowSSS(lightData.shadowPos.xy);
                //if (shadow_sss < EPSILON) return 0.0;

                //float maxDist = SSS_MAXDIST * shadow_sss;
                //return shadow_sss;//max(1.0 - lightDist / maxDist, 0.0);
            }
        #endif
    #endif
#endif
