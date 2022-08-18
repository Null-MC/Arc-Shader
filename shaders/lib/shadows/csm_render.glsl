#extension GL_ARB_texture_gather : enable

#ifdef RENDER_VERTEX
    void ApplyShadows(const in vec3 localPos, const in vec3 viewDir) {
        #ifndef SSS_ENABLED
            if (geoNoL > 0.0) {
        #endif
            #ifdef RENDER_SHADOW
                mat4 matShadowModelView = gl_ModelViewMatrix;
            #else
                mat4 matShadowModelView = shadowModelView;
            #endif

            //vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
            vec3 shadowViewPos = (matShadowModelView * vec4(localPos, 1.0)).xyz;

            #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                //vec3 viewDir = -normalize(viewPos);
                float geoNoV = dot(vNormal, viewDir);

                vec3 localViewDir = normalize(cameraPosition);
                vec3 parallaxLocalPos = localPos + (localViewDir / geoNoV) * PARALLAX_DEPTH;
                vec3 parallaxShadowViewPos = (matShadowModelView * vec4(parallaxLocalPos, 1.0)).xyz;
            #endif

            cascadeSizes[0] = GetCascadeDistance(0);
            cascadeSizes[1] = GetCascadeDistance(1);
            cascadeSizes[2] = GetCascadeDistance(2);
            cascadeSizes[3] = GetCascadeDistance(3);

            // matShadowProjections[0] = GetShadowCascadeProjectionMatrix(0);
            // matShadowProjections[1] = GetShadowCascadeProjectionMatrix(1);
            // matShadowProjections[2] = GetShadowCascadeProjectionMatrix(2);
            // matShadowProjections[3] = GetShadowCascadeProjectionMatrix(3);

            GetShadowCascadeProjectionMatrix_AsParts(0, matShadowProjections_scale[0], matShadowProjections_translation[0]);
            GetShadowCascadeProjectionMatrix_AsParts(1, matShadowProjections_scale[1], matShadowProjections_translation[1]);
            GetShadowCascadeProjectionMatrix_AsParts(2, matShadowProjections_scale[2], matShadowProjections_translation[2]);
            GetShadowCascadeProjectionMatrix_AsParts(3, matShadowProjections_scale[3], matShadowProjections_translation[3]);

            // for (int i = 0; i < 4; i++) {
            //     shadowPos[i] = (matShadowProjections[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;

            //     vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
            //     shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;

            //     // #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
            //     //     // TODO: Get shadow position with max parallax offset
            //     //     shadowParallaxPos[i] = (matShadowProjections[i] * vec4(parallaxShadowViewPos, 1.0)).xyz;
            //     //     shadowParallaxPos[i] = shadowParallaxPos[i] * 0.5 + 0.5;

            //     //     shadowParallaxPos[i].xy = shadowParallaxPos[i].xy * 0.5 + shadowCascadePos;
            //     // #endif
            // }
        #ifndef SSS_ENABLED
            }
            //else {
            //    shadowCascade = -1;
            //}
        #endif
    }
#endif

#ifdef RENDER_FRAG
    const float cascadeTexSize = shadowMapSize * 0.5;
    const int pcf_sizes[4] = int[](4, 3, 2, 1);
    const int pcf_max = 4;

    float SampleDepth(const in vec2 shadowPos, const in vec2 offset) {
        #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
            return textureLod(shadowtex1, shadowPos + offset, 0).r;
        #elif defined SHADOW_ENABLE_HWCOMP
            return textureLod(shadowtex0, shadowPos + offset, 0).r;
        #else
            ivec2 itex = ivec2((shadowPos + offset) * shadowMapSize);
            return texelFetch(shadowtex1, itex, 0).r;
        #endif
    }

    // vec2 GetProjectionSize(const in int index) {
    //     return 2.0 / vec2(matShadowProjections[index][0].x, matShadowProjections[index][1].y);
    // }

    float GetNearestDepth(const in PbrLightData lightData, const in vec2 blockOffset, out int cascade) {
        float depth = 1.0;
        cascade = -1;

        float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

        for (int i = 0; i < 4; i++) {
            vec2 shadowTilePos = lightData.shadowTilePos[i]; //GetShadowCascadeClipPos(i);
            vec2 clipMin = shadowTilePos + 2.0 * shadowPixelSize;
            vec2 clipMax = shadowTilePos + 0.5 - 4.0 * shadowPixelSize;

            // Ignore if outside cascade bounds
            if (lightData.shadowPos[i].x < clipMin.x || lightData.shadowPos[i].x >= clipMax.x
             || lightData.shadowPos[i].y < clipMin.y || lightData.shadowPos[i].y >= clipMax.y) continue;

            //vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjections[i][0].x, matShadowProjections[i][1].y);
            vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[i].xy;
            vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize;
            vec2 finalPixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;
            float texDepth = SampleDepth(lightData.shadowPos[i].xy, finalPixelOffset);

            // TODO: ADD BIAS!

            if (texDepth < depth) {
                depth = texDepth;
                cascade = i;
            }
        }

        return depth;
    }

    float GetCascadeBias(const in float geoNoL, const in int cascade) {
        //vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjections[cascade][0].x, matShadowProjections[cascade][1].y);
        vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[cascade].xy;
        float maxProjSize = max(shadowProjectionSize.x, shadowProjectionSize.y);
        //float maxProjSize = shadowProjectionSizes[cascade].x * shadowProjectionSizes[cascade].y;
        //float maxProjSize = length(shadowProjectionSizes[cascade]);
        //const float cascadePixelSize = 1.0 / cascadeTexSize;
        float zRangeBias = 0.05 / (3.0 * far);

        maxProjSize = pow(maxProjSize, 1.3);

        #if SHADOW_FILTER == 1
            float xySizeBias = 0.004 * maxProjSize * shadowPixelSize;// * tile_dist_bias_factor * 4.0;
        #else
            float xySizeBias = 0.004 * maxProjSize * shadowPixelSize;// * tile_dist_bias_factor;
        #endif

        float bias = mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;

        //bias += pow(1.0 - geoNoL, 16.0);

        return bias;
    }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareDepth(const in vec3 shadowPos, const in vec2 pixelOffset, const in float bias) {
        #ifdef SHADOW_ENABLE_HWCOMP
            #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                return textureLod(shadowtex1HW, shadowPos + vec3(pixelOffset, -bias), 0);
            #else
                return textureLod(shadowtex1, shadowPos + vec3(pixelOffset, -bias), 0);
            #endif
        #else
            float shadowDepth = textureLod(shadowtex1, shadowPos.xy + pixelOffset, 0).r;
            return step(shadowPos.z - bias + EPSILON, shadowDepth);
        #endif
    }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareNearestDepth(const in PbrLightData lightData, const in vec2 blockOffset) {
        float texComp = 1.0;
        for (int i = 3; i >= 0 && texComp > 0.0; i--) {
            vec2 shadowTilePos = lightData.shadowTilePos[i];//GetShadowCascadeClipPos(i);
            vec2 clipMin = shadowTilePos + 2.0 * shadowPixelSize;
            vec2 clipMax = shadowTilePos + 0.5 - 4.0 * shadowPixelSize;

            // Ignore if outside cascade bounds
            if (lightData.shadowPos[i].x < clipMin.x || lightData.shadowPos[i].x >= clipMax.x
             || lightData.shadowPos[i].y < clipMin.y || lightData.shadowPos[i].y >= clipMax.y) continue;

            //vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjections[i][0].x, matShadowProjections[i][1].y);
            vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[i].xy;
            vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSize;
            vec2 pixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

            //float bias = GetCascadeBias(geoNoL, i);
            texComp = min(texComp, CompareDepth(lightData.shadowPos[i], pixelOffset, lightData.shadowBias[i]));
        }

        return max(texComp, 0.0);
    }

    #ifdef SHADOW_COLOR
        vec3 GetShadowColor(const in PbrLightData lightData) {
            int cascade = -1;
            float depthLast = 1.0;
            for (int i = 0; i < 4; i++) {
                vec2 shadowTilePos = lightData.shadowTilePos[i]; //GetShadowCascadeClipPos(i);
                if (lightData.shadowPos[i].x < shadowTilePos.x || lightData.shadowPos[i].x > shadowTilePos.x + 0.5
                 || lightData.shadowPos[i].y < shadowTilePos.y || lightData.shadowPos[i].y > shadowTilePos.y + 0.5) continue;

                //float shadowBias = GetCascadeBias(geoNoL, i);
                float waterDepth = textureLod(shadowtex0, lightData.shadowPos[i].xy, 0).r;
                //float waterShadow = step(waterDepth, shadowPos[i].z - shadowBias);

                if (lightData.shadowPos[i].z - lightData.shadowBias[i] > waterDepth && waterDepth < depthLast) {
                    depthLast = waterDepth;
                    cascade = i;
                }
            }

            if (cascade < 0) return vec3(1.0);

            //surface has translucent object between it and the sun. modify its color.
            //if the block light is high, modify the color less.
            vec3 color = textureLod(shadowcolor0, lightData.shadowPos[cascade].xy, 0).rgb;
            return RGBToLinear(color);

            //make colors more intense when the shadow light color is more opaque.
            //return mix(vec3(1.0), color, shadowLightColor.a);
        }
    #endif

    vec2 GetPixelRadius(const in int cascade, const in float blockRadius) {
        float texSize = shadowMapSize * 0.5;
        //vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjections[cascade][0].x, matShadowProjections[cascade][1].y);
        vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[cascade].xy;
        return blockRadius * (texSize / shadowProjectionSize) * shadowPixelSize;
    }

    #if SHADOW_FILTER != 0
        float GetShadowing_PCF(const in PbrLightData lightData, const in float blockRadius, const in int sampleCount) {
            #ifdef SHADOW_DITHER
                float dither = 0.5 + 0.5*GetScreenBayerValue();
            #endif

            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 blockOffset = poissonDisk[i] * blockRadius;

                #ifdef SHADOW_DITHER
                    blockOffset *= dither;
                #endif

                shadow += 1.0 - CompareNearestDepth(lightData, blockOffset);
            }

            return shadow / sampleCount;
        }
    #endif

    #if SHADOW_FILTER == 2
        // PCF + PCSS
        float FindBlockerDistance(const in PbrLightData lightData, const in float blockRadius, const in int sampleCount, out int cascade) {
            //float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
            //float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
            float avgBlockerDistance = 0.0;
            int blockers = 0;
            cascade = -1;

            for (int i = 0; i < sampleCount; i++) {
                int sampleCascade;
                vec2 blockOffset = poissonDisk[i] * blockRadius;
                float texDepth = GetNearestDepth(lightData, blockOffset, sampleCascade);

                //float bias = GetCascadeBias(geoNoL, sampleCascade);

                if (texDepth < lightData.shadowPos[sampleCascade].z - lightData.shadowBias[sampleCascade]) {
                    avgBlockerDistance += texDepth;
                    cascade = sampleCascade;
                    blockers++;
                }
            }

            if (blockers == sampleCount) return 1.0;
            return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
        }

        float GetShadowing(const in PbrLightData lightData) {
            // blocker search
            int cascade;
            int blockerSampleCount = POISSON_SAMPLES;
            float blockerDistance = FindBlockerDistance(lightData, SHADOW_PCF_SIZE, blockerSampleCount, cascade);
            if (cascade < 0 || blockerDistance <= 0.0) return 1.0;
            if (blockerDistance == 1.0) return 0.0;

            // penumbra estimation
            float penumbraWidth = (lightData.shadowPos[cascade].z - blockerDistance) / blockerDistance;

            // percentage-close filtering
            float blockRadius = min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0) * SHADOW_PCF_SIZE; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = POISSON_SAMPLES;
            //vec2 pixelRadius = GetPixelRadius(cascade, blockRadius);
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

            return 1.0 - GetShadowing_PCF(lightData, blockRadius, pcfSampleCount);
        }
    #elif SHADOW_FILTER == 1
        // PCF
        float GetShadowing(const in PbrLightData lightData) {
            int sampleCount = POISSON_SAMPLES;
            //vec2 pixelRadius = GetPixelRadius(cascade, SHADOW_PCF_SIZE);
            //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            return 1.0 - GetShadowing_PCF(lightData, SHADOW_PCF_SIZE, sampleCount);
        }
    #elif SHADOW_FILTER == 0
        // Unfiltered
        float GetShadowing(const in PbrLightData lightData) {
            #ifdef SHADOW_ENABLE_HWCOMP
                return CompareNearestDepth(lightData, vec2(0.0));
            #else
                int cascade;
                float texDepth = GetNearestDepth(lightData, vec2(0.0), cascade);

                //float bias = GetCascadeBias(geoNoL, cascade);
                return step(lightData.shadowPos[cascade].z - lightData.shadowBias[cascade], texDepth + EPSILON);
            #endif
        }
    #endif

    #ifdef SSS_ENABLED
        float SampleShadowSSS(const in vec2 shadowPos) {
            uint data = textureLod(shadowcolor1, shadowPos, 0).g;
            return unpackUnorm4x8(data).a;
        }

        #if SSS_FILTER != 0
            float GetShadowing_PCF_SSS(const in PbrLightData lightData, const in float blockRadius, const in int sampleCount) {
                #ifdef SSS_DITHER
                    float dither = 0.5 + 0.5*GetScreenBayerValue();
                #endif

                float light = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    int cascade;
                    vec2 blockOffset = poissonDisk[i] * blockRadius;
                    float texDepth = GetNearestDepth(lightData, blockOffset, cascade);

                    //vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjections[cascade][0].x, matShadowProjections[cascade][1].y);
                    vec2 shadowProjectionSize = 2.0 / matShadowProjections_scale[cascade].xy;
                    vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSize) * shadowPixelSize;
                    vec2 pixelOffset = blockOffset * pixelPerBlockScale;
                    
                    #ifdef SSS_DITHER
                        pixelOffset *= dither;
                    #endif

                    //float bias = GetCascadeBias(geoNoL, cascade);
                    float shadow_sss = SampleShadowSSS(lightData.shadowPos[cascade].xy + pixelOffset);
                    float dist = max(lightData.shadowPos[cascade].z - lightData.shadowBias[cascade] - texDepth, 0.0) * far * 3.0;
                    light += max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                }

                return light / sampleCount;
            }
        #endif

        #if SSS_FILTER == 2
            // PCF + PCSS
            float GetShadowSSS(const in PbrLightData lightData) {
                int cascade;
                float texDepth = GetNearestDepth(lightData, vec2(0.0), cascade);
                float dist = max(lightData.shadowPos[cascade].z - texDepth, 0.0) * 4.0 * far;
                float distF = 1.0 + 2.0*saturate(dist / SSS_MAXDIST);

                int sampleCount = SSS_PCF_SAMPLES;
                float blockRadius = SSS_PCF_SIZE * distF;
                vec2 pixelRadius = GetPixelRadius(cascade, blockRadius);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(lightData, blockRadius, sampleCount);
            }
        #elif SSS_FILTER == 1
            // PCF
            float GetShadowSSS(const in PbrLightData lightData) {
                int sampleCount = POISSON_SAMPLES;
                //vec2 pixelRadius = GetPixelRadius(cascade, SHADOW_PCF_SIZE);
                //if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(lightData, SHADOW_PCF_SIZE, sampleCount);
            }
        #elif SSS_FILTER == 0
            // Unfiltered
            float GetShadowSSS(const in PbrLightData lightData) {
                int cascade;
                float texDepth = GetNearestDepth(lightData, vec2(0.0), cascade);
                //float bias = GetCascadeBias(geoNoL, cascade);
                float dist = max(lightData.shadowPos[cascade].z - lightData.shadowBias[cascade] - texDepth, 0.0) * far * 3.0;
                float shadow_sss = SampleShadowSSS(lightData.shadowPos[cascade].xy);
                return max(shadow_sss - dist / SSS_MAXDIST, 0.0);
            }
        #endif
    #endif
#endif
