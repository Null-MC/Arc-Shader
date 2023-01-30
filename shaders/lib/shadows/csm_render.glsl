int GetShadowSampleCascade(const in vec3 shadowPos[4], const in float blockRadius) {
    // #ifdef SHADOW_CSM_FITRANGE
    //     const int max = 3;
    // #else
    //     const int max = 4;
    // #endif

    for (int i = 0; i < 4; i++) {
        vec2 padding = blockRadius / shadowProjectionSize[i];

        // Ignore if outside tile bounds
        //vec2 shadowTilePos = GetShadowCascadeClipPos(i);
        vec2 clipMin = shadowProjectionPos[i] + padding;
        vec2 clipMax = shadowProjectionPos[i] + 0.5 - padding;

        if (clamp(shadowPos[i].xy, clipMin, clipMax) == shadowPos[i].xy) return i;
    }

    return -1;
    // #ifdef SHADOW_CSM_FITRANGE
    //     return 3;
    // #else
    //     return -1;
    // #endif
}

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

    void SetNearestDepths(inout LightData lightData) {
        float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

        const float shadowPcfSize = SHADOW_PCF_SIZE * 0.01;
        lightData.shadowCascade = GetShadowSampleCascade(lightData.shadowPos, shadowPcfSize);

        if (lightData.shadowCascade >= 0) {
            // TODO: ADD BIAS?

            lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos[lightData.shadowCascade].xy, vec2(0.0));
            lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos[lightData.shadowCascade].xy, vec2(0.0));
        }
        else {
            lightData.opaqueShadowDepth = 1.0;
            lightData.transparentShadowDepth = 1.0;
        }
    }

    float GetNearestOpaqueDepth(const in vec3 shadowPos[4], const in vec2 blockOffset, out int cascade) {
        float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

        cascade = -1;
        float depthNearest = 1.0;
        for (int i = 3; i >= 0; i--) {
            vec2 clipMin = shadowProjectionPos[i] + 2.0 * shadowPixelSize;
            vec2 clipMax = shadowProjectionPos[i] + 0.5 - 4.0 * shadowPixelSize;

            if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
             || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

            vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize[i];
            vec2 finalPixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

            float texDepth = SampleOpaqueDepth(shadowPos[i].xy, finalPixelOffset);

            // TODO: ADD BIAS!

            if (texDepth < depthNearest) {
                depthNearest = texDepth;
                cascade = i;
            }
        }

        return depthNearest;
    }

    float GetNearestTransparentDepth(const in vec3 shadowPos[4], const in vec2 blockOffset, out int cascade) {
        cascade = -1;
        float depthNearest = 1.0;
        for (int i = 0; i < 4; i++) {
            vec2 clipMin = shadowProjectionPos[i] + 2.0 * shadowPixelSize;
            vec2 clipMax = shadowProjectionPos[i] + 0.5 - 4.0 * shadowPixelSize;

            if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
             || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

            vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize[i];
            vec2 finalPixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

            float texDepth = SampleTransparentDepth(shadowPos[i].xy, finalPixelOffset);

            if (texDepth < depthNearest) {
                depthNearest = texDepth;
                cascade = i;
            }
        }

        return depthNearest;
    }

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
    float CompareNearestOpaqueDepth(const in vec3 shadowPos[4], const in float shadowBias[4], const in vec2 blockOffset) {
        float texComp = 1.0;
        for (int i = 3; i >= 0 && texComp > 0.0; i--) {
            //vec2 shadowTilePos = shadowTilePos[i];//GetShadowCascadeClipPos(i);
            vec2 clipMin = shadowProjectionPos[i] + 2.0 * shadowPixelSize;
            vec2 clipMax = shadowProjectionPos[i] + 0.5 - 4.0 * shadowPixelSize;

            // Ignore if outside cascade bounds
            if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
             || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

            vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize[i];
            vec2 pixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

            texComp = min(texComp, CompareOpaqueDepth(shadowPos[i], pixelOffset, shadowBias[i]));
        }

        return max(texComp, 0.0);
    }

    float GetWaterShadowDepth(const in LightData lightData, const in int cascade) {
        float waterTexDepth = textureLod(shadowtex0, lightData.shadowPos[cascade].xy, 0).r;
        return lightData.shadowPos[cascade].z - lightData.shadowBias[cascade] - waterTexDepth;
    }

    #ifdef SHADOW_COLOR
        vec3 GetShadowColor(const in vec2 shadowPos) {
            //if (lightData.shadowPos[lightData.shadowCascade].z - lightData.transparentShadowDepth < lightData.shadowBias[lightData.shadowCascade]) return vec3(1.0);

            vec3 color = textureLod(shadowcolor0, shadowPos, 0).rgb;
            //color = RGBToLinear(color);
            return color;
        }
    #endif

    vec2 GetPixelRadius(const in int cascade, const in float blockRadius) {
        return blockRadius * (cascadeTexSize / shadowProjectionSize[cascade]) * shadowPixelSize;
    }

    #if SHADOW_FILTER != 0
        const float shadowPcfSize = SHADOW_PCF_SIZE * 0.01;

        float GetShadowing_PCF(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount, const in int cascade) {
            //float bias = GetShadowBias(cascade, lightData.geoNoL);

            float startAngle = hash12(gl_FragCoord.xy) * TAU;
            vec2 rotation = vec2(cos(startAngle), sin(startAngle));

            float angleDiff = -TAU / sampleCount;
            vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
            mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                rotation *= rotationStep;
                float noiseDist = hash13(vec3(gl_FragCoord.xy, i));
                vec2 pixelOffset = rotation * (1.0 - pow2(noiseDist)) * pixelRadius;

                shadow += 1.0 - CompareOpaqueDepth(lightData.shadowPos[cascade], pixelOffset, lightData.shadowBias[cascade]);
            }

            return shadow / sampleCount;
        }
    #endif

    #if SHADOW_FILTER == 2
        // PCF + PCSS
        float FindBlockerDistance(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount, const in int cascade) {
            float startAngle = hash12(gl_FragCoord.xy + 33.3) * TAU;
            vec2 rotation = vec2(cos(startAngle), sin(startAngle));

            float angleDiff = -TAU / sampleCount;
            vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
            mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);
            
            float blockers = 0.0;
            float avgBlockerDistance = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                rotation *= rotationStep;
                float noiseDist = hash13(vec3(gl_FragCoord.xy, i + 33.3));
                vec2 pixelOffset = rotation * (1.0 - pow2(noiseDist)) * pixelRadius;

                float texDepth = SampleOpaqueDepth(lightData.shadowPos[cascade].xy, pixelOffset);

                float hitDist = max((lightData.shadowPos[cascade].z - lightData.shadowBias[cascade]) - texDepth, 0.0);

                avgBlockerDistance += hitDist * (far * 3.0);
                blockers += step(0.0, hitDist);

                // if (texDepth < lightData.shadowPos[cascade].z - lightData.shadowBias[cascade]) {
                //     avgBlockerDistance += texDepth;
                //     blockers++;
                // }
            }

            //if (blockers == sampleCount) return 1.0;
            return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
        }

        float GetShadowing(const in LightData lightData) {
            //int cascade = GetShadowSampleCascade(lightData.shadowPos, lightData.shadowProjectionSize, shadowPcfSize);
            if (lightData.shadowCascade < 0) return 1.0;

            vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, shadowPcfSize);
            
            // blocker search
            int blockerSampleCount = SHADOW_PCSS_SAMPLES;
            //vec2 blockerPixelRadius = GetPixelRadius(lightData.shadowCascade, shadowPcfSize);
            float blockerDistance = FindBlockerDistance(lightData, pixelRadius, blockerSampleCount, lightData.shadowCascade);
            if (blockerDistance <= 0.0) return 1.0;
            //if (blockerDistance == 1.0) return 0.0;

            // penumbra estimation
            //float penumbraWidth = (lightData.shadowPos[lightData.shadowCascade].z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            pixelRadius *= min(blockerDistance * 0.3, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;
            //pixelRadius = max(pixelRadius, 1.5 * shadowPixelSize);

            int pcfSampleCount = SHADOW_PCF_SAMPLES;
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
            return 1.0 - GetShadowing_PCF(lightData, pixelRadius, pcfSampleCount, lightData.shadowCascade);
        }
    #elif SHADOW_FILTER == 1
        // PCF
        float GetShadowing(const in LightData lightData) {
            //int cascade = GetShadowSampleCascade(lightData.shadowPos, lightData.shadowProjectionSize, shadowPcfSize);
            if (lightData.shadowCascade < 0) return 1.0;

            int sampleCount = SHADOW_PCF_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, shadowPcfSize);
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            return 1.0 - GetShadowing_PCF(lightData, pixelRadius, sampleCount, lightData.shadowCascade);
        }
    #elif SHADOW_FILTER == 0
        // Unfiltered
        float GetShadowing(const in LightData lightData) {
            //int cascade = GetShadowSampleCascade(lightData.shadowPos, lightData.shadowProjectionSize, shadowPcfSize);
            if (lightData.shadowCascade < 0) return 1.0;

            float surfaceDepth = lightData.shadowPos[lightData.shadowCascade].z - EPSILON;
            float texDepth = lightData.opaqueShadowDepth + lightData.shadowBias[lightData.shadowCascade];
            return step(surfaceDepth, texDepth);
        }
    #endif

    #ifdef SSS_ENABLED
        // float SampleShadowSSS(const in vec2 shadowPos) {
        //     #ifdef SHADOW_COLOR
        //         uint data = textureLod(shadowcolor1, shadowPos, 0).g;
        //         return unpackUnorm4x8(data).a;
        //     #else
        //         return textureLod(shadowcolor0, shadowPos, 0).r;
        //     #endif
        // }

        float GetShadowing_PCF_SSS(const in LightData lightData, const in vec2 pixelRadius, const in int sampleCount) {
            float startAngle = hash12(gl_FragCoord.xy + 11.1) * TAU;
            vec2 rotation = vec2(cos(startAngle), sin(startAngle));

            float angleDiff = -TAU / sampleCount;
            vec2 angleStep = vec2(cos(angleDiff), sin(angleDiff));
            mat2 rotationStep = mat2(angleStep, -angleStep.y, angleStep.x);

            float light = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                rotation *= rotationStep;
                float noiseDist = hash13(vec3(gl_FragCoord.xy, i));
                vec2 pixelOffset = rotation * noiseDist * pixelRadius;

                float texDepth = SampleOpaqueDepth(lightData.shadowPos[lightData.shadowCascade].xy, pixelOffset);

                //float shadow_sss = SampleShadowSSS(lightData.shadowPos[lightData.shadowCascade].xy + pixelOffset);

                //float dist = max(lightData.shadowPos[lightData.shadowCascade].z + lightData.shadowBias[lightData.shadowCascade] - texDepth, 0.0) * (far * 3.0);
                float weight = 1.0;
                if (texDepth < lightData.shadowPos[lightData.shadowCascade].z + lightData.shadowBias[lightData.shadowCascade])
                    weight = max(1.0 - noiseDist, 0.0);//SampleShadowSSS(lightData.shadowPos.xy + pixelOffset);
                
                light += weight;//max(shadow_sss - dist / SSS_MAXDIST, 0.0);
            }

            return light / sampleCount;
        }

        // PCF + PCSS
        float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float traceDist) {
            if (lightData.shadowCascade < 0) return 0.0;

            float texDepth = SampleOpaqueDepth(lightData.shadowPos[lightData.shadowCascade].xy, vec2(0.0));
            traceDist = max(lightData.shadowPos[lightData.shadowCascade].z + lightData.shadowBias[lightData.shadowCascade] - texDepth, 0.0) * (far * 3.0);
            float blockRadius = SSS_PCF_SIZE * saturate(traceDist / SSS_MAXDIST) * (1.0 - 0.85*materialSSS);

            int sampleCount = SSS_PCF_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, blockRadius);
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            return GetShadowing_PCF_SSS(lightData, pixelRadius, sampleCount);
        }
    #endif
#endif
