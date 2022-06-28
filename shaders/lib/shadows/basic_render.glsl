#ifdef RENDER_VERTEX
	void ApplyShadows(const in vec3 viewPos) {
        #ifndef SSS_ENABLED
    		if (geoNoL > 0.0) {
        #endif
			vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos, 1.0))).xyz;

			shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

			#if SHADOW_TYPE == 2
				float distortFactor = getDistortFactor(shadowPos.xy);
				shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
				shadowPos.z -= SHADOW_DISTORTED_BIAS * SHADOW_BIAS_SCALE * (distortFactor * distortFactor) / abs(geoNoL);
			#elif SHADOW_TYPE == 1
				float range = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);
				float shadowResScale = range / shadowMapSize;
				float bias = SHADOW_BASIC_BIAS * shadowResScale * SHADOW_BIAS_SCALE;
				shadowPos.z -= min(bias / abs(geoNoL), 0.1);
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
	// #if SHADOW_COLORS == 1
	// 	vec3 GetShadowColor() {
	// 		//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
	// 		//perform a 2nd check to see if there's anything translucent between us and the sun.
	// 		if (texture2D(shadowtex0, shadowPos.xy).r >= shadowPos.z) return vec3(1.0);

	// 		//surface has translucent object between it and the sun. modify its color.
	// 		//if the block light is high, modify the color less.
	// 		vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
	// 		vec3 color = RGBToLinear(shadowLightColor.rgb);

	// 		//make colors more intense when the shadow light color is more opaque.
	// 		return mix(vec3(1.0), color, shadowLightColor.a);
	// 	}
	// #endif

    #ifdef SSS_ENABLED
        float SampleShadowSSS(const in vec2 shadowPos) {
            return texture2D(shadowcolor0, shadowPos).r;
        }
    #endif

	float SampleDepth(const in vec4 shadowPos, const in vec2 offset) {
        #if !defined IS_OPTIFINE && defined SHADOW_ENABLE_HWCOMP
            return texture2D(shadowtex1, shadowPos.xy + offset * shadowPos.w).r;
        #else
            return texture2D(shadowtex0, shadowPos.xy + offset * shadowPos.w).r;
        #endif
	}

    #ifdef SHADOW_ENABLE_HWCOMP
        // returns: [0] when depth occluded, [1] otherwise
        float CompareDepth(const in vec4 shadowPos, const in vec2 offset) {
            #ifndef IS_OPTIFINE
                return shadow2D(shadowtex1HW, shadowPos.xyz + vec3(offset * shadowPos.w, 0.0)).r;
            #else
                return shadow2D(shadowtex1, shadowPos.xyz + vec3(offset * shadowPos.w, 0.0)).r;
            #endif
        }
    #endif

    #if SHADOW_FILTER != 0
        // PCF
        #ifdef SHADOW_ENABLE_HWCOMP
            float GetShadowing_PCF(const in vec4 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
                float shadow = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;
                    shadow += 1.0 - CompareDepth(shadowPos, pixelOffset);
                }

                return shadow / sampleCount;
            }
        #else
            float GetShadowing_PCF(const in vec4 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
                float shadow = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;
                    float texDepth = SampleDepth(shadowPos, pixelOffset);
                    shadow += step(texDepth + EPSILON, shadowPos.z);
                }

                return shadow / sampleCount;
            }
        #endif

        #ifdef SSS_ENABLED
            float GetShadowing_PCF_SSS(const in vec4 shadowPos, const in vec2 pixelRadius, const in int sampleCount) {
                float light = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 pixelOffset = poissonDisk[i] * pixelRadius;
                    float texDepth = SampleDepth(shadowPos, pixelOffset);

                    float shadow_sss = SampleShadowSSS(shadowPos.xy + pixelOffset);
                    float dist = max(shadowPos.z - texDepth, 0.0) * 4.0 * far;
                    light += max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                }

                return light / sampleCount;
            }
        #endif
    #endif

    #if SHADOW_FILTER != 0
        vec2 GetShadowPixelRadius(const in float blockRadius) {
            vec2 shadowProjectionSize = 2.0 / vec2(shadowProjection[0].x, shadowProjection[1].y);

            #if SHADOW_TYPE == 2
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

		float GetShadowing(const in vec4 shadowPos, out float lightSSS) {
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
			return 1.0 - GetShadowing_PCF(shadowPos, pixelRadius, pcfSampleCount);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing(const in vec4 shadowPos) {
            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

			return 1.0 - GetShadowing_PCF(shadowPos, pixelRadius, sampleCount);
		}

        #ifdef SSS_ENABLED
            float GetShadowSSS(const in vec4 shadowPos) {
                int sampleCount = POISSON_SAMPLES;
                vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);
                if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

                return GetShadowing_PCF_SSS(shadowPos, pixelRadius, sampleCount);
            }
        #endif
	#elif SHADOW_FILTER == 0
        // Unfiltered
		float GetShadowing(const in vec4 shadowPos) {
            #ifdef SHADOW_ENABLE_HWCOMP
                return CompareDepth(shadowPos, vec2(0.0));
            #else
                float texDepth = SampleDepth(shadowPos, vec2(0.0));
                return step(shadowPos.z - EPSILON, texDepth);
            #endif
		}

        #ifdef SSS_ENABLED
            float GetShadowSSS(const in vec4 shadowPos) {
                float texDepth = SampleDepth(shadowPos, vec2(0.0));
                float dist = max(shadowPos.z - texDepth, 0.0) * 4.0 * far;

                float shadow_sss = SampleShadowSSS(shadowPos.xy);
                return max(shadow_sss - dist / SSS_MAXDIST, 0.0);
            }
        #endif
	#endif
#endif
