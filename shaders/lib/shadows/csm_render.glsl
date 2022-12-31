vec3 GetShadowSampleCascade(const in mat4 matShadowProjection[4], const in vec3 shadowViewPos, out int cascade) {
    for (int i = 0; i < 3; i++) {
        // Ignore if outside tile bounds
        vec2 shadowTilePos = GetShadowCascadeClipPos(i);
        vec2 clipMin = shadowTilePos;
        vec2 clipMax = shadowTilePos + 0.5;

        #if SHADOW_FILTER != 0
            vec2 shadowProjectionSize = 2.0 / vec2(
                matShadowProjection[i][0].x,
                matShadowProjection[i][1].y);

            vec2 padding = shadowPcfSize / shadowProjectionSize;
            clipMin += padding;
            clipMax -= padding;
        #endif

        vec3 shadowPos = (matShadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;

        if (clamp(shadowPos.xy, clipMin, clipMax) == shadowPos.xy) {
            cascade = i;
            return shadowPos;
        }
    }

    cascade = 3;
    return (matShadowProjection[3] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
}

// void SetShadowSampleCascade(inout LightData lightData, const in vec3 shadowViewPos) {
//     for (int i = 0; i < 3; i++) {
//         // Ignore if outside tile bounds
//         vec2 shadowTilePos = GetShadowCascadeClipPos(i);
//         vec2 clipMin = shadowTilePos;
//         vec2 clipMax = shadowTilePos + 0.5;

//         #if SHADOW_FILTER != 0
//             vec2 shadowProjectionSize = 2.0 / vec2(
//                 lightData.matShadowProjection[i][0].x,
//                 lightData.matShadowProjection[i][1].y);

//             vec2 padding = shadowPcfSize / shadowProjectionSize;
//             clipMin += padding;
//             clipMax -= padding;
//         #endif

//         lightData.shadowPos = (lightData.matShadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;

//         if (clamp(lightData.shadowPos.xy, clipMin, clipMax) == lightData.shadowPos.xy) {
//             lightData.shadowCascade = i;
//             return;
//         }
//     }

//     lightData.shadowPos = (lightData.matShadowProjection[3] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
//     lightData.shadowCascade = 3;
// }

#ifdef RENDER_FRAG
    const float cascadeTexSize = shadowMapSize * 0.5;
    const int pcf_sizes[4] = int[](4, 3, 2, 1);
    const int pcf_max = 4;

    float SampleOpaqueDepth(const in vec2 shadowPos, const in vec2 offset) {
        //ivec2 itex = ivec2((shadowPos + offset) * shadowMapSize);
        //return texelFetch(shadowtex1, itex, 0).r;
        return textureLod(shadowtex1, shadowPos + offset, 0).r;
    }

    float SampleTransparentDepth(const in vec2 shadowPos, const in vec2 offset) {
        return textureLod(shadowtex0, shadowPos + offset, 0).r;
    }

    // void SetNearestDepths(inout LightData lightData) {
    //     //float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

    //     lightData.opaqueShadowCascade = GetShadowSampleCascade(lightData);
    //     lightData.transparentShadowCascade = lightData.opaqueShadowCascade;

    //     if (lightData.opaqueShadowCascade >= 0) {
    //         // TODO: ADD BIAS?

    //         lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos.xy, vec2(0.0));
    //         lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos.xy, vec2(0.0));
    //     }
    //     else {
    //         lightData.opaqueShadowDepth = 1.0;
    //         //lightData.opaqueShadowCascade = -1;
    //         lightData.transparentShadowDepth = 1.0;
    //         //lightData.transparentShadowCascade = -1;
    //     }
    // }

    // float GetNearestOpaqueDepth(const in vec3 shadowPos[4], const in vec2 shadowTilePos[4], const in vec2 blockOffset, out int cascade) {
    //     float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

    //     cascade = -1;
    //     float depthNearest = 1.0;
    //     for (int i = 3; i >= 0; i--) {
    //         vec2 clipMin = shadowTilePos[i] + 2.0 * shadowPixelSize;
    //         vec2 clipMax = shadowTilePos[i] + 0.5 - 4.0 * shadowPixelSize;

    //         if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
    //          || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

    //         vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[i].xy;
    //         vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize;
    //         vec2 finalPixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

    //         float texDepth = SampleOpaqueDepth(shadowPos[i].xy, finalPixelOffset);

    //         // TODO: ADD BIAS!

    //         if (texDepth < depthNearest) {
    //             depthNearest = texDepth;
    //             cascade = i;
    //         }
    //     }

    //     return depthNearest;
    // }

    // float GetNearestTransparentDepth(const in vec3 shadowPos[4], const in vec2 shadowTilePos[4], const in vec2 blockOffset, out int cascade) {
    //     cascade = -1;
    //     float depthNearest = 1.0;
    //     for (int i = 0; i < 4; i++) {
    //         vec2 clipMin = shadowTilePos[i] + 2.0 * shadowPixelSize;
    //         vec2 clipMax = shadowTilePos[i] + 0.5 - 4.0 * shadowPixelSize;

    //         if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
    //          || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

    //         vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[i].xy;
    //         vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize;
    //         vec2 finalPixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

    //         float texDepth = SampleTransparentDepth(shadowPos[i].xy, finalPixelOffset);

    //         if (texDepth < depthNearest) {
    //             depthNearest = texDepth;
    //             cascade = i;
    //         }
    //     }

    //     return depthNearest;
    // }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareOpaqueDepth(const in vec3 shadowPos, const in vec2 pixelOffset, const in float bias) {
        #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
            return textureLod(shadowtex1HW, shadowPos + vec3(pixelOffset, -bias), 0);
        #else
            float shadowDepth = textureLod(shadowtex1, shadowPos.xy + pixelOffset, 0).r;
            return step(shadowPos.z - bias + EPSILON, shadowDepth);
        #endif
    }

    // returns: [0] when depth occluded, [1] otherwise
    // float CompareNearestOpaqueDepth(const in vec3 shadowPos[4], const in vec2 shadowTilePos[4], const in float shadowBias[4], const in vec2 blockOffset) {
    //     float texComp = 1.0;
    //     for (int i = 3; i >= 0 && texComp > 0.0; i--) {
    //         vec2 shadowTilePos = shadowTilePos[i];//GetShadowCascadeClipPos(i);
    //         vec2 clipMin = shadowTilePos + 2.0 * shadowPixelSize;
    //         vec2 clipMax = shadowTilePos + 0.5 - 4.0 * shadowPixelSize;

    //         // Ignore if outside cascade bounds
    //         if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
    //          || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

    //         //vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjections[i][0].x, matShadowProjections[i][1].y);
    //         vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[i].xy;
    //         vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize;
    //         vec2 pixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

    //         texComp = min(texComp, CompareOpaqueDepth(shadowPos[i], pixelOffset, shadowBias[i]));
    //     }

    //     return max(texComp, 0.0);
    // }

    float GetWaterShadowDepth(const in LightData lightData) {
        float waterTexDepth = textureLod(shadowtex0, lightData.shadowPos.xy, 0).r;
        return lightData.shadowPos.z - lightData.shadowBias - waterTexDepth;
    }

    #ifdef SHADOW_COLOR
        vec3 GetShadowColor(const in LightData lightData) {
            if (lightData.shadowPos.z - lightData.transparentShadowDepth < EPSILON) return vec3(1.0);

            vec3 color = textureLod(shadowcolor0, lightData.shadowPos.xy, 0).rgb;
            return RGBToLinear(color);
        }
    #endif

    vec2 GetPixelRadius(const in int cascade, const in float blockRadius) {
        //float texSize = shadowMapSize * 0.5;
        vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[cascade].xy;
        return blockRadius * (cascadeTexSize / shadowProjectionSize) * shadowPixelSize;
    }

    #if SHADOW_FILTER != 0
        const float shadowPcfSize = SHADOW_PCF_SIZE * 0.01;

        float GetShadowing_PCF(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
            float surfaceDepth = lightData.shadowPos.z - EPSILON;
            float texDepth = lightData.opaqueShadowDepth + lightData.shadowBias;
            float shadow = step(texDepth, surfaceDepth);

            for (int i = 1; i < sampleCount; i++) {
                vec2 pixelOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;
                shadow += 1.0 - CompareOpaqueDepth(lightData.shadowPos, pixelOffset, lightData.shadowBias);
            }

            return shadow / sampleCount;
        }
    #endif

    #if SHADOW_FILTER == 2
        // PCF + PCSS
        float FindBlockerDistance(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
            //float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
            //float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
            float avgBlockerDistance = 0.0;
            int blockers = 0;

            for (int i = 0; i < sampleCount; i++) {
                vec2 pixelOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;
                float texDepth = SampleOpaqueDepth(lightData.shadowPos.xy, pixelOffset);

                if (texDepth < lightData.shadowPos.z - lightData.shadowBias) {
                    avgBlockerDistance += texDepth;
                    blockers++;
                }
            }

            if (blockers == sampleCount) return 1.0;
            return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
        }

        float GetShadowing(const in LightData lightData) {
            // blocker search
            int blockerSampleCount = POISSON_SAMPLES;
            vec2 blockerPixelRadius = GetPixelRadius(lightData.shadowCascade, shadowPcfSize);
            float blockerDistance = FindBlockerDistance(lightData, blockerPixelRadius, blockerSampleCount);
            if (blockerDistance <= 0.0) return 1.0;
            if (blockerDistance == 1.0) return 0.0;

            // penumbra estimation
            float penumbraWidth = (lightData.shadowPos.z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            float blockRadius = min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0) * shadowPcfSize; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, blockRadius);
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

            return 1.0 - GetShadowing_PCF(lightData, pixelRadius, pcfSampleCount);
        }
    #elif SHADOW_FILTER == 1
        // PCF
        float GetShadowing(const in LightData lightData) {
            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, shadowPcfSize);
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            return 1.0 - GetShadowing_PCF(lightData, pixelRadius, sampleCount);
        }
    #elif SHADOW_FILTER == 0
        // Unfiltered
        float GetShadowing(const in LightData lightData) {
            float surfaceDepth = lightData.shadowPos.z - EPSILON;
            float texDepth = lightData.opaqueShadowDepth + lightData.shadowBias;
            return step(surfaceDepth, texDepth);
        }
    #endif

    #ifdef SSS_ENABLED
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
                vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[lightData.shadowCascade].xy;
                vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize) * shadowPixelSize;
                float light = 0.0;
                
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * pixelRadius;
                    //vec2 pixelOffset = blockOffset * pixelPerBlockScale;

                    float texDepth = SampleOpaqueDepth(lightData.shadowPos.xy, pixelOffset);

                    float shadow_sss = SampleShadowSSS(lightData.shadowPos.xy + pixelOffset);

                    float dist = max(lightData.shadowPos.z + lightData.shadowBias - texDepth, 0.0) * far * 3.0;
                    light += max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                }

                return light / sampleCount;
            }
        #endif

        #ifdef SSS_SCATTER
            // PCF + PCSS
            float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float traceDist) {
                float texDepth = SampleOpaqueDepth(lightData.shadowPos.xy, vec2(0.0));
                traceDist = max(lightData.shadowPos.z + lightData.shadowBias - texDepth, 0.0) * 3.0 * far;
                float blockRadius = SSS_PCF_SIZE * saturate(traceDist / SSS_MAXDIST) * (1.0 - 0.85*materialSSS);

                int sampleCount = SSS_PCF_SAMPLES;
                vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, blockRadius);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(lightData, pixelRadius, sampleCount);
            }
        #else
            // Unfiltered
            float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float lightDist) {
                lightDist = max(lightData.shadowPos.z + lightData.shadowBias - lightData.opaqueShadowDepth, 0.0) * far * 3.0;

                float shadow_sss = SampleShadowSSS(lightData.shadowPos.xy);
                if (shadow_sss < EPSILON) return 0.0;

                float maxDist = SSS_MAXDIST * shadow_sss;
                return materialSSS * max(1.0 - lightDist / maxDist, 0.0);
            }
        #endif
    #endif
#endif
