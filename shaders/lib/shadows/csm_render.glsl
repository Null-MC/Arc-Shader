const float cascadeTexSize = shadowMapSize * 0.5;
const int pcf_sizes[4] = int[](4, 3, 2, 1);
const int pcf_max = 4;


bool IsSampleWithinCascade(const in vec2 shadowPos, const in int cascade, const in float blockRadius) {
    vec2 padding = blockRadius / shadowProjectionSize[cascade];// + 8.0 * shadowPixelSize;
    vec2 clipMin = shadowProjectionPos[cascade] + padding;
    vec2 clipMax = shadowProjectionPos[cascade] + 0.5 - padding;

    return all(greaterThan(shadowPos, clipMin)) && all(lessThan(shadowPos, clipMax));
}

int GetShadowSampleCascade(const in vec3 shadowPos[4], const in float blockRadius) {
    if (IsSampleWithinCascade(shadowPos[0].xy, 0, blockRadius)) return 0;
    if (IsSampleWithinCascade(shadowPos[1].xy, 1, blockRadius)) return 1;
    if (IsSampleWithinCascade(shadowPos[2].xy, 2, blockRadius)) return 2;
    if (IsSampleWithinCascade(shadowPos[3].xy, 3, blockRadius)) return 3;
    return -1;
}

vec3 GetCascadeShadowPosition(const in vec3 shadowViewPos, out int cascade) {
    cascade = GetShadowCascade(shadowViewPos, -shadowPcfSize);
    if (cascade < 0) return vec3(0.0);

    vec3 clipPos = (cascadeProjection[cascade] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
    clipPos.xy = clipPos.xy * 0.5 + shadowProjectionPos[cascade];
    return clipPos;
}

float SampleOpaqueDepth(const in vec2 shadowPos, const in vec2 offset) {
    //ivec2 itex = ivec2((shadowPos + offset) * shadowMapSize);
    //return texelFetch(shadowtex1, itex, 0).r;
    return textureLod(shadowtex1, shadowPos + offset, 0).r;
}

float SampleTransparentDepth(const in vec2 shadowPos, const in vec2 offset) {
    return textureLod(shadowtex0, shadowPos + offset, 0).r;
}

void SetNearestDepths(inout LightData lightData) {
    //float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

    //lightData.shadowCascade = GetShadowSampleCascade(lightData.shadowPos, shadowPcfSize);
    //vec3 shadowPos = GetCascadeShadowPosition(shadowViewPos, lightData.shadowCascade);
    //lightData.shadowPos[lightData.shadowCascade] = shadowPos;

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

// float GetNearestOpaqueDepth(const in vec3 shadowPos[4], const in vec2 blockOffset, out int cascade) {
//     float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

//     cascade = -1;
//     float depthNearest = 1.0;
//     for (int i = 3; i >= 0; i--) {
//         vec2 clipMin = shadowProjectionPos[i] + 2.0 * shadowPixelSize;
//         vec2 clipMax = shadowProjectionPos[i] + 0.5 - 4.0 * shadowPixelSize;

//         if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
//          || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

//         vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize[i];
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

// float GetNearestTransparentDepth(const in vec3 shadowPos[4], const in vec2 blockOffset, out int cascade) {
//     cascade = -1;
//     float depthNearest = 1.0;
//     for (int i = 0; i < 4; i++) {
//         vec2 clipMin = shadowProjectionPos[i] + 2.0 * shadowPixelSize;
//         vec2 clipMax = shadowProjectionPos[i] + 0.5 - 4.0 * shadowPixelSize;

//         if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
//          || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

//         vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize[i];
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
// float CompareNearestOpaqueDepth(const in vec3 shadowPos[4], const in float shadowBias[4], const in vec2 blockOffset) {
//     float texComp = 1.0;
//     for (int i = 3; i >= 0 && texComp > 0.0; i--) {
//         //vec2 shadowTilePos = shadowTilePos[i];//GetShadowCascadeClipPos(i);
//         vec2 clipMin = shadowProjectionPos[i] + 2.0 * shadowPixelSize;
//         vec2 clipMax = shadowProjectionPos[i] + 0.5 - 4.0 * shadowPixelSize;

//         // Ignore if outside cascade bounds
//         if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
//          || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

//         vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize[i];
//         vec2 pixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

//         texComp = min(texComp, CompareOpaqueDepth(shadowPos[i], pixelOffset, shadowBias[i]));
//     }

//     return max(texComp, 0.0);
// }

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
    float GetShadowing_PCF(const in vec3 shadowPos, const in vec2 pixelRadius, const in float bias) {
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
                vec2 pixelOffset = rotation * (1.0 - pow2(noiseDist)) * pixelRadius;
            #endif

            shadow += 1.0 - CompareOpaqueDepth(shadowPos, pixelOffset, bias);
        }

        return shadow * rcp(SHADOW_PCF_SAMPLES);
    }
#endif

#if SHADOW_FILTER == 2
    // PCF + PCSS
    float FindBlockerDistance(const in LightData lightData, const in vec2 pixelRadius, const in int cascade) {
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
                vec2 pixelOffset = rotation * (1.0 - pow2(noiseDist)) * pixelRadius;
            #endif

            float texDepth = SampleOpaqueDepth(lightData.shadowPos[cascade].xy, pixelOffset);

            float hitDist = max((lightData.shadowPos[cascade].z - lightData.shadowBias[cascade]) - texDepth, 0.0);

            avgBlockerDistance += hitDist * (far * 3.0);
            blockers += step(0.0, hitDist);
        }

        return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
    }

    float GetShadowing(const in LightData lightData) {
        if (lightData.shadowCascade < 0) return 1.0;

        vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, shadowPcfSize);
        
        float blockerDistance = FindBlockerDistance(lightData, pixelRadius, lightData.shadowCascade);
        if (blockerDistance <= 0.0) return 1.0;

        float bias = lightData.shadowBias[lightData.shadowCascade];// + blockerDistance;

        pixelRadius *= min(blockerDistance * SHADOW_PENUMBRA_SCALE, 1.0);
        return 1.0 - GetShadowing_PCF(lightData.shadowPos[lightData.shadowCascade], pixelRadius, bias);
    }
#elif SHADOW_FILTER == 1
    // PCF
    float GetShadowing(const in LightData lightData) {
        if (lightData.shadowCascade < 0) return 1.0;

        vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, shadowPcfSize);
        float bias = lightData.shadowBias[lightData.shadowCascade];

        return 1.0 - GetShadowing_PCF(lightData.shadowPos[lightData.shadowCascade], pixelRadius, bias);
    }
#elif SHADOW_FILTER == 0
    // Unfiltered
    float GetShadowing(const in LightData lightData) {
        if (lightData.shadowCascade < 0) return 1.0;

        float surfaceDepth = lightData.shadowPos[lightData.shadowCascade].z - EPSILON;
        float texDepth = lightData.opaqueShadowDepth + lightData.shadowBias[lightData.shadowCascade];
        return step(surfaceDepth, texDepth);
    }
#endif

#ifdef SSS_ENABLED
    float GetShadowing_PCF_SSS(const in LightData lightData, const in vec2 pixelRadius) {
        #ifdef IRIS_FEATURE_SSBO
            float dither = InterleavedGradientNoise(gl_FragCoord.xy);
            float angle = fract(dither) * TAU;
            float s = sin(angle), c = cos(angle);
            mat2 rotation = mat2(c, -s, s, c);
        #else
            float startAngle = hash12(gl_FragCoord.xy + 11.1) * TAU;
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
                float noiseDist = hash13(vec3(gl_FragCoord.xy, i));
                vec2 pixelOffset = rotation * noiseDist * pixelRadius;
            #endif

            float texDepth = SampleOpaqueDepth(lightData.shadowPos[lightData.shadowCascade].xy, pixelOffset);

            float hitDepth = max((lightData.shadowPos[lightData.shadowCascade].z - lightData.shadowBias[lightData.shadowCascade]) - texDepth, 0.0) * (far * 3.0);
            light += max(1.0 - hitDepth / SSS_MAXDIST, 0.0);
        }

        return light * rcp(SSS_PCF_SAMPLES);
    }

    // PCF + PCSS
    float GetShadowSSS(const in LightData lightData, const in float materialSSS, out float lightDist) {
        if (lightData.shadowCascade < 0) {
            lightDist = 0.0;
            return 0.0;
        }

        lightDist = max(lightData.shadowPos[lightData.shadowCascade].z - lightData.shadowBias[lightData.shadowCascade] - lightData.opaqueShadowDepth, 0.0) * (far * 3.0);
        vec2 pixelRadius = GetPixelRadius(lightData.shadowCascade, SSS_PCF_SIZE * lightDist);

        float sss = GetShadowing_PCF_SSS(lightData, pixelRadius);
        return max(sss * materialSSS, 0.0);
    }
#endif
