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

            mat4 matShadowProjections[4];
            matShadowProjections[0] = GetShadowCascadeProjectionMatrix(0);
            matShadowProjections[1] = GetShadowCascadeProjectionMatrix(1);
            matShadowProjections[2] = GetShadowCascadeProjectionMatrix(2);
            matShadowProjections[3] = GetShadowCascadeProjectionMatrix(3);

			for (int i = 0; i < 4; i++) {
				shadowProjectionSizes[i] = 2.0 / vec2(
					matShadowProjections[i][0].x,
					matShadowProjections[i][1].y);
				
				shadowPos[i] = (matShadowProjections[i] * vec4(shadowViewPos, 1.0)).xyz;

				vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
				shadowPos[i] = shadowPos[i] * 0.5 + 0.5;

				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;

                #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                    // TODO: Get shadow position with max parallax offset
                    shadowParallaxPos[i] = (matShadowProjections[i] * vec4(parallaxShadowViewPos, 1.0)).xyz;
                    shadowParallaxPos[i] = shadowParallaxPos[i] * 0.5 + 0.5;

                    shadowParallaxPos[i].xy = shadowParallaxPos[i].xy * 0.5 + shadowCascadePos;
                #endif
			}

			shadowCascade = GetShadowCascade(matShadowProjections);
        #ifndef SSS_ENABLED
            }
            else {
                shadowCascade = -1;
            }
        #endif
	}
#endif

#ifdef RENDER_FRAG
	//#define PCF_MAX_RADIUS 0.16

    const float cascadeTexSize = shadowMapSize * 0.5;
	const int pcf_sizes[4] = int[](4, 3, 2, 1);
	const int pcf_max = 4;

	float SampleDepth(const in vec2 shadowPos, const in vec2 offset) {
        #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
            return texture(shadowtex1, shadowPos + offset).r;
        #elif defined SHADOW_ENABLE_HWCOMP
            return texture(shadowtex0, shadowPos + offset).r;
        #else
            ivec2 itex = ivec2((shadowPos + offset) * shadowMapSize);
            return texelFetch(shadowtex1, itex, 0).r;
        #endif
	}

	float GetNearestDepth(const in vec3 shadowPos[4], const in vec2 blockOffset, out int cascade) {
		float depth = 1.0;
		cascade = -1;

		float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

		for (int i = 0; i < 4; i++) {
			vec2 shadowTilePos = GetShadowCascadeClipPos(i);
            vec2 clipMin = shadowTilePos + 2.0 * shadowPixelSize;
            vec2 clipMax = shadowTilePos + 0.5 - 4.0 * shadowPixelSize;

            // Ignore if outside cascade bounds
			if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
			 || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

			vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSizes[i];
			vec2 pixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;
			float texDepth = SampleDepth(shadowPos[i].xy, pixelOffset);

            if (texDepth < depth) {
				depth = texDepth;
				cascade = i;
			}
		}

		return depth;
	}

    float GetCascadeBias(const in int cascade) {
        float maxProjSize = max(shadowProjectionSizes[cascade].x, shadowProjectionSizes[cascade].y);
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

    vec2 GetPixelRadius(const in float blockRadius) {
        float texSize = shadowMapSize * 0.5;
        return blockRadius * (texSize / shadowProjectionSizes[shadowCascade]) * shadowPixelSize;
    }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareDepth(const in vec3 shadowPos, const in vec2 offset, const in float bias) {
        #ifdef SHADOW_ENABLE_HWCOMP
            #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                return textureLod(shadowtex1HW, shadowPos + vec3(offset, -bias), 0);
            #else
                return textureLod(shadowtex1, shadowPos + vec3(offset, -bias), 0);
            #endif
        #else
            float shadowDepth = textureLod(shadowtex1, shadowPos.xy + offset, 0).r;
            return step(shadowPos.z - bias + EPSILON, shadowDepth);
        #endif
    }

    // returns: [0] when depth occluded, [1] otherwise
    float CompareNearestDepth(const in vec3 shadowPos[4], const in vec2 blockOffset) {
        float texComp = 1.0;
        for (int i = 0; i < 4 && texComp > 0.0; i++) {
            vec2 shadowTilePos = GetShadowCascadeClipPos(i);
            vec2 clipMin = shadowTilePos + 2.0 * shadowPixelSize;
            vec2 clipMax = shadowTilePos + 0.5 - 4.0 * shadowPixelSize;

            // Ignore if outside cascade bounds
            if (shadowPos[i].x < clipMin.x || shadowPos[i].x >= clipMax.x
             || shadowPos[i].y < clipMin.y || shadowPos[i].y >= clipMax.y) continue;

            vec2 pixelPerBlockScale = cascadeTexSize / shadowProjectionSizes[i];
            vec2 pixelOffset = blockOffset * pixelPerBlockScale * shadowPixelSize;

            float bias = GetCascadeBias(i);
            texComp = min(texComp, CompareDepth(shadowPos[i], pixelOffset, bias));
        }

        return max(texComp, 0.0);
    }

    #ifndef RENDER_DEFERRED
        #if SHADOW_FILTER != 0
            float GetShadowing_PCF(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
                float shadow = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 blockOffset = poissonDisk[i] * blockRadius;
                    shadow += 1.0 - CompareNearestDepth(shadowPos, blockOffset);
                }

                return shadow / sampleCount;
            }
        #endif

    	#if SHADOW_COLORS == 1
    		vec3 GetShadowColor() {
    			int cascade = -1;
    			float depthLast = 1.0;
    			for (int i = 0; i < 4; i++) {
    				vec2 shadowTilePos = GetShadowCascadeClipPos(i);
    				if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
    				if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

    				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
    				//perform a 2nd check to see if there's anything translucent between us and the sun.
    				float depth = texture(shadowtex0, shadowPos[i].xy).r;
    				if (depth + EPSILON < 1.0 && depth < shadowPos[i].z && depth < depthLast) {
    					depthLast = depth;
    					cascade = i;
    				}
    			}

    			if (cascade < 0) return vec3(1.0);

    			//surface has translucent object between it and the sun. modify its color.
    			//if the block light is high, modify the color less.
    			uint data = texture(shadowcolor0, shadowPos[cascade].xy).r;
                vec3 color = unpackUnorm4x8(data).rgb;
    			color = RGBToLinear(color);

    			//make colors more intense when the shadow light color is more opaque.
    			return mix(vec3(1.0), color, shadowLightColor.a);
    		}
    	#endif

    	#if SHADOW_FILTER == 2
    		// PCF + PCSS
    		float FindBlockerDistance(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
    			//float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
    			//float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
    			float avgBlockerDistance = 0.0;
    			int blockers = 0;

    			for (int i = 0; i < sampleCount; i++) {
                    int cascade;
    				vec2 blockOffset = poissonDisk[i] * blockRadius;
    				float texDepth = GetNearestDepth(shadowPos, blockOffset, cascade);

                    float bias = GetCascadeBias(cascade);

    				if (texDepth < shadowPos[cascade].z - bias) {
    					avgBlockerDistance += texDepth;
    					blockers++;
    				}
    			}

                if (blockers == sampleCount) return 1.0;
    			return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
    		}

    		float GetShadowing(const in vec3 shadowPos[4]) {
    			// blocker search
    			int blockerSampleCount = POISSON_SAMPLES;
    			float blockerDistance = FindBlockerDistance(shadowPos, SHADOW_PCF_SIZE, blockerSampleCount);
    			if (blockerDistance <= 0.0) return 1.0;
                if (blockerDistance == 1.0) return 0.0;

    			// penumbra estimation
    			float penumbraWidth = (shadowPos[shadowCascade].z - blockerDistance) / blockerDistance;

    			// percentage-close filtering
    			float blockRadius = min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0) * SHADOW_PCF_SIZE; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

                int pcfSampleCount = POISSON_SAMPLES;
    			vec2 pixelRadius = GetPixelRadius(blockRadius);
    			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

    			return 1.0 - GetShadowing_PCF(shadowPos, blockRadius, pcfSampleCount);
    		}
    	#elif SHADOW_FILTER == 1
    		// PCF
    		float GetShadowing(const in vec3 shadowPos[4]) {
                int sampleCount = POISSON_SAMPLES;
                vec2 pixelRadius = GetPixelRadius(SHADOW_PCF_SIZE);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

    			return 1.0 - GetShadowing_PCF(shadowPos, SHADOW_PCF_SIZE, sampleCount);
    		}
    	#elif SHADOW_FILTER == 0
    		// Unfiltered
    		float GetShadowing(const in vec3 shadowPos[4]) {
                //int cascade = GetCascadeSampleIndex(shadowPos, vec2(0.0));
                //if (cascade < 0) return 1.0;

                //float bias = GetCascadeBias(cascade);

                #ifdef SHADOW_ENABLE_HWCOMP
                    return CompareNearestDepth(shadowPos, vec2(0.0));
                    //return CompareDepth(shadowPos[cascade], vec2(0.0), bias);
                #else
        			int cascade;
        			float texDepth = GetNearestDepth(shadowPos, vec2(0.0), cascade);

                    float bias = GetCascadeBias(cascade);
        			return step(shadowPos[cascade].z - bias, texDepth + EPSILON);
                #endif
    		}
    	#endif

        #ifdef SSS_ENABLED
            vec4 SampleShadowColorSSS(const in vec2 shadowPos) {
                uint data = texture(shadowcolor0, shadowPos).r;
                return unpackUnorm4x8(data);
            }

            #if SSS_FILTER != 0
                float GetShadowing_PCF_SSS(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
                    float light = 0.0;
                    for (int i = 0; i < sampleCount; i++) {
                        int cascade;
                        vec2 blockOffset = poissonDisk[i] * blockRadius;
                        float texDepth = GetNearestDepth(shadowPos, blockOffset, cascade);

                        vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSizes[cascade]) * shadowPixelSize;
                        vec2 pixelOffset = blockOffset * pixelPerBlockScale;

                        float bias = GetCascadeBias(cascade);
                        float shadow_sss = SampleShadowColorSSS(shadowPos[cascade].xy + pixelOffset).a;
                        float dist = max(shadowPos[cascade].z - bias - texDepth, 0.0) * far * 3.0;
                        light += max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                    }

                    return light / sampleCount;
                }
            #endif

            #if SSS_FILTER == 2
                // PCF + PCSS
                float GetShadowSSS(const in vec3 shadowPos[4]) {
                    int cascade;
                    float texDepth = GetNearestDepth(shadowPos, vec2(0.0), cascade);
                    float dist = max(shadowPos[cascade].z - texDepth, 0.0) * 4.0 * far;
                    float distF = 1.0 + 2.0*saturate(dist / SSS_MAXDIST);

                    int sampleCount = SSS_PCF_SAMPLES;
                    float blockRadius = SSS_PCF_SIZE * distF;
                    vec2 pixelRadius = GetPixelRadius(blockRadius);
                    if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                    return GetShadowing_PCF_SSS(shadowPos, blockRadius, sampleCount);
                }
            #elif SSS_FILTER == 1
                // PCF
                float GetShadowSSS(const in vec3 shadowPos[4]) {
                    int sampleCount = POISSON_SAMPLES;
                    vec2 pixelRadius = GetPixelRadius(SHADOW_PCF_SIZE);
                    if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                    return GetShadowing_PCF_SSS(shadowPos, SHADOW_PCF_SIZE, sampleCount);
                }
            #elif SSS_FILTER == 0
                // Unfiltered
                float GetShadowSSS(const in vec3 shadowPos[4]) {
                    int cascade;
                    float texDepth = GetNearestDepth(shadowPos, vec2(0.0), cascade);
                    float bias = GetCascadeBias(cascade);
                    float dist = max(shadowPos[cascade].z - bias - texDepth, 0.0) * far * 3.0;
                    float shadow_sss = SampleShadowColorSSS(shadowPos[cascade].xy).a;
                    return max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                }
            #endif
        #endif
    #endif
#endif
