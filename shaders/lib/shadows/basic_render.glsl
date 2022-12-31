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
            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;
                
                shadow += 1.0 - CompareOpaqueDepth(lightData.shadowPos, pixelOffset, lightData.shadowBias);
            }

            return 1.0 - smoothstep(0.0, 1.0, shadow / sampleCount);
        }
    #endif

    #if SHADOW_FILTER == 2
        // PCF + PCSS
        float FindBlockerDistance(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
            float avgBlockerDistance = 0.0;
            int blockers = 0;

            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;

                vec2 t = lightData.shadowPos.xy + pixelOffset;
                if (saturate(t) != t) continue;

                float texDepth = SampleOpaqueDepth(lightData.shadowPos, pixelOffset);

                if (texDepth < lightData.shadowPos.z + lightData.shadowBias) {
                    avgBlockerDistance += texDepth;
                    blockers++;
                }
            }

            return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
        }

        float GetShadowing(const in LightData lightData) {
            const float shadowPcfSize = SHADOW_PCF_SIZE * 0.01;
            
            int blockerSampleCount = POISSON_SAMPLES;
            int pcfSampleCount = POISSON_SAMPLES;

            // blocker search
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, shadowPcfSize);
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;

            float blockerDistance = FindBlockerDistance(lightData, pixelRadius * 2.0, blockerSampleCount);
            if (blockerDistance < EPSILON) return 1.0;
            //if (blockerDistance == 1.0) return 0.0;

            // penumbra estimation
            float penumbraWidth = (lightData.shadowPos.z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            pixelRadius *= min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
            return GetShadowing_PCF(lightData, pixelRadius, pcfSampleCount);
        }
    #elif SHADOW_FILTER == 1
        // PCF
        float GetShadowing(const in LightData lightData) {
            const float shadowPcfSize = SHADOW_PCF_SIZE * 0.01;

            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, shadowPcfSize);
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            return GetShadowing_PCF(lightData, pixelRadius, sampleCount);
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
            float GetShadowing_PCF_SSS(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
                float light = 0.0;
                float maxWeight = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;

                    float texDepth = SampleOpaqueDepth(lightData.shadowPos, pixelOffset);

                    float weight = 1.0 - saturate(dot(poissonDisk[i], poissonDisk[i]));
                    maxWeight += weight;

                    if (texDepth < lightData.shadowPos.z + lightData.shadowBias)
                        weight *= SampleShadowSSS(lightData.shadowPos.xy + pixelOffset);

                    light += weight;
                }

                if (maxWeight < EPSILON) return 1.0;
                return light / maxWeight;
            }
        #endif

        #ifdef SSS_SCATTER
            // PCF + PCSS
            float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float lightDist) {
                lightDist = max(lightData.shadowPos.z + lightData.shadowBias - lightData.opaqueShadowDepth, 0.0) * ShadowMaxDepth;

                int sampleCount = SSS_PCF_SAMPLES;
                float blockRadius = SSS_PCF_SIZE * lightDist;
                vec2 pixelRadius = GetShadowPixelRadius(lightData.shadowPos.xy, blockRadius);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(lightData, pixelRadius, sampleCount);
            }
        #else
            // Unfiltered
            float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float lightDist) {
                lightDist = max(lightData.shadowPos.z + lightData.shadowBias - lightData.opaqueShadowDepth, 0.0) * ShadowMaxDepth;
                return SampleShadowSSS(lightData.shadowPos.xy);
            }
        #endif
    #endif
#endif
