#ifdef RENDER_VERTEX
    void ApplyShadows(const in vec3 localPos, const in vec3 viewDir) {
        #ifndef SSS_ENABLED
            if (geoNoL > 0.0) {
        #endif
            shadowPos = shadowProjection * (shadowModelView * vec4(localPos, 1.0));

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
                shadowBias = GetShadowBias(geoNoL, distortFactor);
            #elif SHADOW_TYPE == SHADOW_TYPE_BASIC
                shadowBias = GetShadowBias(geoNoL);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

            #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                // TODO: Get shadow position with max parallax offset
                shadowParallaxPos = (matShadowProjections * vec4(parallaxShadowViewPos, 1.0)).xyz;
                shadowParallaxPos.xyz = shadowParallaxPos.xyz * 0.5 + 0.5;
            #endif
        #ifndef SSS_ENABLED
            }
        #endif
    }
#endif

#ifdef RENDER_FRAG
    float SampleDepth(const in vec4 shadowPos, const in vec2 offset) {
        #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
            return texture(shadowtex1, shadowPos.xy + offset * shadowPos.w).r;
        #elif defined SHADOW_ENABLE_HWCOMP
            return texture(shadowtex0, shadowPos.xy + offset * shadowPos.w).r;
        #else
            return texture(shadowtex1, shadowPos.xy + offset * shadowPos.w).r;
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
        vec3 CompareColor(const in vec3 shadowPos, const in float shadowBias) {
            //#ifdef SHADOW_ENABLE_HWCOMP
            //    float waterShadow = 1.0 - textureLod(shadowtex0, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0);
            //#else
            float waterDepth = textureLod(shadowtex0, shadowPos.xy, 0).r;
            float waterShadow = step(waterDepth, shadowPos.z - shadowBias); // TODO: bias might be backwards? idk
            //#endif

            if (waterShadow < EPSILON) return vec3(1.0);
            return textureLod(shadowcolor0, shadowPos.xy, 0).rgb;
        }
    #endif

    // // returns: XYZ:color; W=[0] when depth occluded, W=[1] otherwise
    // vec4 CompareDepthColor(const in vec4 shadowPos, const in vec2 offset, const in float shadowBias) {
    //     vec4 result = vec4(1.0);

    //     #ifdef SHADOW_ENABLE_HWCOMP
    //         #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
    //             result.w = textureLod(shadowtex1HW, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0);
    //         #else
    //             result.w = textureLod(shadowtex1, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0);
    //         #endif
    //     #else
    //         float shadowDepth = textureLod(shadowtex1, shadowPos.xy + offset * shadowPos.w, 0).r;
    //         result.w = step(shadowPos.z + EPSILON, shadowDepth + shadowBias);
    //     #endif

    //     #ifdef SHADOW_COLOR
    //         if (result.w > EPSILON) {
    //             #ifdef SHADOW_ENABLE_HWCOMP
    //                 float waterShadow = 1.0 - textureLod(shadowtex0, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0);
    //             #else
    //                 float waterDepth = textureLod(shadowtex0, shadowPos.xyz + vec3(offset * shadowPos.w, -shadowBias), 0).r;
    //                 float waterShadow = 1.0 - step(waterDepth, shadowPos.z);
    //             #endif

    //             if (waterShadow > EPSILON)
    //                 result.rgb = textureLod(shadowcolor0, _shadowPos.xy, 0).rgb;
    //         }
    //     #endif

    //     return result;
    // }

    #ifndef RENDER_DEFERRED
        vec2 GetShadowPixelRadius(const in float blockRadius) {
            vec2 shadowProjectionSize = 2.0 / vec2(shadowProjection[0].x, shadowProjection[1].y);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(shadowPos.xy * 2.0 - 1.0);
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
                float shadow = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;
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
                vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

                // blocker search
                int blockerSampleCount = POISSON_SAMPLES;
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
                float blockerDistance = FindBlockerDistance(shadowPos, pixelRadius, blockerSampleCount);
                if (blockerDistance < 0.0) return 1.0;
                if (blockerDistance == 1.0) return 0.0;

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
                vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                float biasMax = shadowBias * (max(pixelRadius.x, pixelRadius.y) / shadowPixelSize);
                return 1.0 - GetShadowing_PCF(shadowPos, biasMax, pixelRadius, sampleCount);
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

        // #ifdef SHADOW_COLOR
        //     vec4 SampleShadowColor(const in vec2 shadowPos) {
        //         uint data = texture(shadowcolor0, shadowPos).r;
        //         return unpackUnorm4x8(data);
        //     }
        // #endif

        #if defined SSS_ENABLED
            float SampleShadowSSS(const in vec2 shadowPos) {
                uint data = textureLod(shadowcolor1, shadowPos, 0).g;
                return unpackUnorm4x8(data).b;
            }

            #if SSS_FILTER != 0
                float GetShadowing_PCF_SSS(const in vec4 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
                    float light = 0.0;
                    for (int i = 0; i < sampleCount; i++) {
                        vec2 pixelOffset = poissonDisk[i] * pixelRadius;
                        float texDepth = SampleDepth(shadowPos, pixelOffset);
                        light += step(shadowPos.z, texDepth);

                        if (texDepth < shadowPos.z) {
                            float shadow_sss = SampleShadowSSS(shadowPos.xy + pixelOffset);

                            float dist = max(shadowPos.z - texDepth, 0.0) * 4.0 * far;
                            light += max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                        }
                    }

                    return light / sampleCount;
                }
            #endif

            #if SSS_FILTER == 2
                // PCF + PCSS
                float GetShadowSSS(const in vec4 shadowPos) {
                    float texDepth = SampleDepth(shadowPos, vec2(0.0));
                    float dist = max(shadowPos.z - texDepth, 0.0) * 4.0 * far;
                    float distF = 1.0 + 2.0*saturate(dist / SSS_MAXDIST);

                    int sampleCount = SSS_PCF_SAMPLES;
                    vec2 pixelRadius = GetShadowPixelRadius(SSS_PCF_SIZE * distF);
                    if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                    return GetShadowing_PCF_SSS(shadowPos, pixelRadius, sampleCount);
                }
            #elif SSS_FILTER == 1
                // PCF
                float GetShadowSSS(const in vec4 shadowPos) {
                    int sampleCount = SSS_PCF_SAMPLES;
                    vec2 pixelRadius = GetShadowPixelRadius(SSS_PCF_SIZE);
                    if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                    return GetShadowing_PCF_SSS(shadowPos, pixelRadius, sampleCount);
                }
            #elif SSS_FILTER == 0
                // Unfiltered
                float GetShadowSSS(const in vec4 shadowPos) {
                    float texDepth = SampleDepth(shadowPos, vec2(0.0));
                    float dist = max(shadowPos.z - texDepth, 0.0) * 4.0 * far;

                    float shadow_sss = SampleShadowSSS(shadowPos.xy);
                    return max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                }
            #endif
        #endif
    #endif
#endif
