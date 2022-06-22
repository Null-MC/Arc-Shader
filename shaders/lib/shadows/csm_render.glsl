#extension GL_ARB_texture_gather : enable

const float tile_dist_bias_factor = 0.012288;

#ifdef RENDER_VERTEX
	void ApplyShadows(const in vec3 viewPos) {
		if (geoNoL > 0.0) {
            #ifdef RENDER_SHADOW
                mat4 matShadowModelView = gl_ModelViewMatrix;
            #else
                mat4 matShadowModelView = shadowModelView;
            #endif

			vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
            vec3 shadowViewPos = (matShadowModelView * vec4(localPos, 1.0)).xyz;

            #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                vec3 viewDir = -normalize(viewPos);
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
				shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5;

				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;

                #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                    // TODO: Get shadow position with max parallax offset
                    shadowParallaxPos[i] = (matShadowProjections[i] * vec4(parallaxShadowViewPos, 1.0)).xyz;
                    shadowParallaxPos[i] = shadowParallaxPos[i] * 0.5 + 0.5;

                    shadowParallaxPos[i].xy = shadowParallaxPos[i].xy * 0.5 + shadowCascadePos;
                #endif
			}

			shadowCascade = GetShadowCascade(matShadowProjections);
		}
		else {
			shadowCascade = -1;

			// #ifdef RENDER_TEXTURED
			// 	shadowPos[0] = vec3(0.0);
			// 	shadowPos[1] = vec3(0.0);
			// 	shadowPos[2] = vec3(0.0);
			// 	shadowPos[3] = vec3(0.0);
			// #else
			// 	shadowPos[0] = vec4(0.0);
			// 	shadowPos[1] = vec4(0.0);
			// 	shadowPos[2] = vec4(0.0);
			// 	shadowPos[3] = vec4(0.0);
			// #endif
		}
	}
#endif

#ifdef RENDER_FRAG
	#define PCF_MAX_RADIUS 0.16

	const int pcf_sizes[4] = int[](4, 3, 2, 1);
	const int pcf_max = 4;

    #if !defined SHADOW_ENABLE_HWCOMP || SHADOW_FILTER == 2
    	float SampleDepth(const in vec3 shadowPos[4], const in vec2 offset, const in int tile) {
    		//#if SHADOW_COLORS == 0
    		//	return texture2D(shadowtex0, shadowPos[tile].xy + offset).r;
    		//#else
    			return texture2D(shadowtex1, shadowPos[tile].xy + offset).r;
    		//#endif
    	}

    	float GetNearestDepth(const in vec3 shadowPos[4], const in vec2 blockOffset, out int tile) {
    		float depth = 1.0;
    		tile = -1;

    		float shadowResScale = tile_dist_bias_factor * shadowPixelSize;
    		float texSize = shadowMapSize * 0.5;

    		float texDepth;
    		for (int i = 0; i < 4; i++) {
    			// Ignore if outside tile bounds
    			vec2 shadowTilePos = GetShadowCascadeClipPos(i);
    			if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
    			if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

    			vec2 pixelPerBlockScale = (texSize / shadowProjectionSizes[i]) * shadowPixelSize;
    			
    			vec2 pixelOffset = blockOffset * pixelPerBlockScale;
    			texDepth = SampleDepth(shadowPos, pixelOffset, i);

    			if (i != shadowCascade) {
    				vec2 ratio = (shadowProjectionSizes[shadowCascade] / shadowProjectionSizes[i]) * shadowPixelSize;

    				vec4 samples;
    				samples.x = SampleDepth(shadowPos, pixelOffset + vec2(-1.0, 0.0)*ratio, i);
    				samples.y = SampleDepth(shadowPos, pixelOffset + vec2( 1.0, 0.0)*ratio, i);
    				samples.z = SampleDepth(shadowPos, pixelOffset + vec2( 0.0,-1.0)*ratio, i);
    				samples.w = SampleDepth(shadowPos, pixelOffset + vec2( 0.0, 1.0)*ratio, i);

    				texDepth = min(texDepth, samples.x);
    				texDepth = min(texDepth, samples.y);
    				texDepth = min(texDepth, samples.z);
    				texDepth = min(texDepth, samples.w);
    			}

    			float bias = cascadeSizes[shadowCascade] * shadowResScale * SHADOW_BIAS_SCALE;
    			// TODO: BIAS NEEDS TO BE BASED ON DISTANCE
    			// In theory that should help soften the transition between cascades

    			// TESTING: reduce the depth-range for the nearest cascade only
    			//if (i == 0) bias *= 0.5;

    			if (texDepth < shadowPos[i].z - min(bias / geoNoL, 0.1) && texDepth < depth) {
    				depth = texDepth;
    				tile = i;
    			}
    		}

    		return depth;
    	}
    #endif

    vec2 GetPixelRadius(const in vec2 blockRadius) {
        float texSize = shadowMapSize * 0.5;
        return blockRadius * (texSize / shadowProjectionSizes[shadowCascade]) * shadowPixelSize;
    }

    #ifdef SHADOW_ENABLE_HWCOMP
        // returns: [0] when depth occluded, [1] otherwise
        float CompareDepth(const in vec3 shadowPos[4], const in vec2 offset, const in float bias, const in int tile) {
            //#if SHADOW_FILTER == 2
            //    return shadow2D(shadow, shadowPos[tile].xyz + vec3(offset, -bias)).r;
            //#else
                return shadow2D(shadowtex0, shadowPos[tile].xyz + vec3(offset, -bias)).r;
            //#endif
        }

        // returns: [0] when depth occluded, [1] otherwise
        float CompareNearestDepth(const in vec3 shadowPos[4], const in vec2 blockOffset) {
            //float shadowResScale = tile_dist_bias_factor * shadowPixelSize;
            float cascadeTexSize = shadowMapSize * 0.5;

            float texComp = 1.0;
            for (int i = 0; i < 4 && texComp > 0.0; i++) {
                // Ignore if outside tile bounds
                vec2 shadowTilePos = GetShadowCascadeClipPos(i);
                if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
                if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

                //float bias = cascadeSize[i] * shadowResScale * SHADOW_BIAS_SCALE;
                //bias = min(bias / geoNoL, 0.1);
                // TODO: BIAS NEEDS TO BE BASED ON DISTANCE
                // In theory that should help soften the transition between cascades

                // TESTING: reduce the depth-range for the nearest cascade only
                //if (i == 0) bias *= 0.5;

                float blocksPerPixelScale = max(shadowProjectionSizes[i].x, shadowProjectionSizes[i].y) / cascadeTexSize;

                float zRangeBias = 0.00001;
                float xySizeBias = blocksPerPixelScale * tile_dist_bias_factor;
                float bias = mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;

                vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSizes[i]) * shadowPixelSize;
                
                vec2 pixelOffset = blockOffset * pixelPerBlockScale;
                texComp = min(texComp, CompareDepth(shadowPos, pixelOffset, bias, i));

                // if (texComp > 0.5 && i != shadowCascade) {
                //     vec2 ratio = (shadowProjectionSize[shadowCascade] / shadowProjectionSize[i]) * shadowPixelSize;

                //     texComp -= 1.0 - CompareDepth(pixelOffset + vec2(-0.5, -0.5)*ratio, bias, i);
                //     texComp -= 1.0 - CompareDepth(pixelOffset + vec2( 0.5, -0.5)*ratio, bias, i);
                //     texComp -= 1.0 - CompareDepth(pixelOffset + vec2(-0.5,  0.5)*ratio, bias, i);
                //     texComp -= 1.0 - CompareDepth(pixelOffset + vec2( 0.5,  0.5)*ratio, bias, i);
                // }
            }

            return max(texComp, 0.0);
        }

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
    #elif SHADOW_FILTER != 0
        float GetShadowing_PCF(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
            int tile;
            float texDepth;
            float shadow = 0.0;
            for (int i = 0; i < sampleCount; i++) {
                vec2 blockOffset = poissonDisk[i] * blockRadius;
                float texDepth = GetNearestDepth(shadowPos, blockOffset, tile);
                shadow += step(texDepth + EPSILON, shadowPos[tile].z);
            }

            //if (sampleCount == 1) return shadow;
            return shadow / sampleCount;

            // #if SHADOW_FILTER == 1
            //     float f = 1.0 - max(geoNoL, 0.0);
            //     f = clamp(shadow / sampleCount - 0.8*f, 0.0, 1.0) * (1.0 + 1.0 * f);
            //     return clamp(f, 0.0, 1.0);
            // #else
            //     return expStep(shadow / sampleCount);
            // #endif
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
				float depth = texture2D(shadowtex0, shadowPos[i].xy).r;
				if (depth + EPSILON < 1.0 && depth < shadowPos[i].z && depth < depthLast) {
					depthLast = depth;
					cascade = i;
				}
			}

			if (cascade < 0) return vec3(1.0);

			//surface has translucent object between it and the sun. modify its color.
			//if the block light is high, modify the color less.
			vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos[cascade].xy);
			vec3 color = RGBToLinear(shadowLightColor.rgb);

			//make colors more intense when the shadow light color is more opaque.
			return mix(vec3(1.0), color, shadowLightColor.a);
		}
	#endif

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		#define SHADOW_BLOCKER_SAMPLES 12

		float FindBlockerDistance(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
			// NOTE: This optimization doesn't really help here rn since the search radius is fixed
			//if (blockRadius <= shadowPixelSize) sampleCount = 1;

			//float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
			//float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
			float avgBlockerDistance = 0;
			int blockers = 0;

			int cascade;
			for (int i = 0; i < sampleCount; i++) {
				vec2 blockOffset = poissonDisk[i] * blockRadius;
				float texDepth = GetNearestDepth(shadowPos, blockOffset, cascade);

				if (texDepth < shadowPos[cascade].z) { // - directionalLightShadowMapBias
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

			if (blockers == sampleCount) return 1.0;
			return blockers > 0 ? avgBlockerDistance / blockers : 0.0;
		}

		float GetShadowing(const in vec3 shadowPos[4]) {
			// blocker search
			int blockerSampleCount = SHADOW_BLOCKER_SAMPLES;
			float blockerDistance = FindBlockerDistance(shadowPos, SHADOW_PCF_SIZE, blockerSampleCount);
			if (blockerDistance <= 0.0) return 1.0;
			if (blockerDistance >= 1.0) return 0.0;

			// penumbra estimation
			float penumbraWidth = (shadowPos[shadowCascade].z - blockerDistance) / blockerDistance;

			// percentage-close filtering
			float blockRadius = clamp(penumbraWidth * 75.0, 0.0, 1.0) * SHADOW_PCF_SIZE; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = POISSON_SAMPLES;
			vec2 pixelRadius = GetPixelRadius(vec2(blockRadius));
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

			return 1.0 - GetShadowing_PCF(shadowPos, blockRadius, pcfSampleCount);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing(const in vec3 shadowPos[4]) {
			int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(vec2(SHADOW_PCF_SIZE));
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

			return 1.0 - GetShadowing_PCF(shadowPos, SHADOW_PCF_SIZE, sampleCount);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing(const in vec3 shadowPos[4]) {
            #ifdef SHADOW_ENABLE_HWCOMP
                return CompareNearestDepth(shadowPos, vec2(0.0));
            #else
    			int tile;
    			float texDepth = GetNearestDepth(shadowPos, vec2(0.0), tile);
    			return step(1.0, texDepth + EPSILON);
            #endif
		}
	#endif
#endif
