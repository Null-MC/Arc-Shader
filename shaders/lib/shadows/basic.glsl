//euclidian distance is defined as sqrt(a^2 + b^2 + ...)
//this length function instead does cbrt(a^3 + b^3 + ...)
//this results in smaller distances along the diagonal axes.
float cubeLength(const in vec2 v) {
	return pow(abs(v.x * v.x * v.x) + abs(v.y * v.y * v.y), 1.0 / 3.0);
}

float getDistortFactor(const in vec2 v) {
	return cubeLength(v) + SHADOW_DISTORT_FACTOR;
}

vec3 distort(const in vec3 v, const in float factor) {
	return vec3(v.xy / factor, v.z * 0.5);
}

vec3 distort(const in vec3 v) {
	return distort(v, getDistortFactor(v.xy));
}

#ifdef RENDER_VERTEX
	#ifndef RENDER_SHADOW
		void ApplyShadows(const in vec4 viewPos) {
			// #if defined RENDER_TERRAIN && defined SHADOW_EXCLUDE_FOLIAGE
			// 	//when SHADOW_EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
			// 	//in other words, don't darken the back side of it unless something else is casting a shadow on it.
			// 	if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) geoNoL = 1.0;
			// #endif

			if (geoNoL > 0.0) { //vertex is facing towards the sun
				vec4 playerPos = gbufferModelViewInverse * viewPos;

				#ifdef RENDER_TEXTURED
					shadowPos = (shadowProjection * (shadowModelView * playerPos)).xyz; //convert to shadow screen space
				#else
					shadowPos = shadowProjection * (shadowModelView * playerPos); //convert to shadow screen space
				#endif

				#if SHADOW_TYPE == 2
					float distortFactor = getDistortFactor(shadowPos.xy);
					shadowPos.xyz = distort(shadowPos.xyz, distortFactor); //apply shadow distortion
					shadowPos.z -= SHADOW_DISTORTED_BIAS * SHADOW_BIAS_SCALE * (distortFactor * distortFactor) / abs(geoNoL); //apply shadow bias
				#elif SHADOW_TYPE == 1
					//shadowPos.z *= 0.5;
					float range = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);
					float shadowResScale = range / shadowMapResolution;
					float bias = SHADOW_BASIC_BIAS * shadowResScale * SHADOW_BIAS_SCALE;
					shadowPos.z -= min(bias / abs(geoNoL), 0.1); //apply shadow bias
				#endif

				shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
			}
			else { //vertex is facing away from the sun
				// mark that this vertex does not need to check the shadow map.
				#ifdef RENDER_TEXTURED
					shadowPos = vec3(0.0);
				#else
					shadowPos = vec4(0.0);
				#endif
			}
		}
	#endif
#endif

#ifdef RENDER_FRAG
	#if SHADOW_COLORS == 1
		vec3 GetShadowColor() {
			//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
			//perform a 2nd check to see if there's anything translucent between us and the sun.
			if (texture2D(shadowtex0, shadowPos.xy).r >= shadowPos.z) return vec3(1.0);

			//surface has translucent object between it and the sun. modify its color.
			//if the block light is high, modify the color less.
			vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
			vec3 color = RGBToLinear(shadowLightColor.rgb);

			//make colors more intense when the shadow light color is more opaque.
			return mix(vec3(1.0), color, shadowLightColor.a);
		}
	#endif

	float SampleDepth(const in vec2 offset) {
		#if SHADOW_COLORS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			#ifdef RENDER_TEXTURED
				return texture2D(shadowtex0, shadowPos.xy + offset).r;
			#else
				return texture2DProj(shadowtex0, vec4(shadowPos.xy + offset * shadowPos.w, shadowPos.z, shadowPos.w)).r;
			#endif
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			#ifdef RENDER_TEXTURED
				return texture2D(shadowtex1, shadowPos.xy + offset).r;
			#else
				return texture2DProj(shadowtex1, vec4(shadowPos.xy + offset * shadowPos.w, shadowPos.z, shadowPos.w)).r;
			#endif
		#endif
	}

	#if SHADOW_FILTER != 0
		// PCF
		float GetShadowing_PCF(const in vec2 pixelRadius, const in int sampleCount) {
			float texDepth;
			float shadow = 0.0;
			for (int i = 0; i < sampleCount; i++) {
				vec2 pixelOffset = poissonDisk[i] * pixelRadius;
				float texDepth = SampleDepth(pixelOffset);
				shadow += step(texDepth + EPSILON, shadowPos.z);
			}

			if (sampleCount <= 1) return shadow;

			#if SHADOW_FILTER == 1
				float f = 1.0 - max(geoNoL, 0.0);
				f = clamp(shadow / sampleCount - 0.7*f, 0.0, 1.0) * (1.0 + (1.0/0.3) * f);
				return clamp(f, 0.0, 1.0);
			#else
				return expStep(shadow / sampleCount);
			#endif
		}

		vec2 GetShadowPixelRadius(const in float blockRadius) {
			vec2 shadowProjectionSize = 2.0 / vec2(shadowProjection[0].x, shadowProjection[1].y);

			#if SHADOW_TYPE == 2
				float distortFactor = getDistortFactor(shadowPos.xy * 2.0 - 1.0);
				float maxRes = shadowMapResolution / SHADOW_DISTORT_FACTOR;
				//float maxResPixel = 1.0 / maxRes;

				vec2 pixelPerBlockScale = maxRes / shadowProjectionSize;
				return blockRadius * pixelPerBlockScale * shadowPixelSize * (1.0 - distortFactor);
			#else
				vec2 pixelPerBlockScale = shadowMapResolution / shadowProjectionSize;
				return blockRadius * pixelPerBlockScale * shadowPixelSize;
			#endif
		}
	#endif

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		//#define PCSS_NEAR 1.0
		#define SHADOW_BLOCKER_SAMPLES 12
		//#define SHADOW_LIGHT_SIZE 0.0002

		float FindBlockerDistance(const in vec2 pixelRadius, const in int sampleCount) {
			//float radius = SearchWidth(uvLightSize, shadowPos.z);
			//float radius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
			float avgBlockerDistance = 0;
			int blockers = 0;

			for (int i = 0; i < sampleCount; i++) {
				vec2 offset = poissonDisk[i] * pixelRadius;
				float texDepth = SampleDepth(offset);

				if (texDepth < shadowPos.z) { // - directionalLightShadowMapBias
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

			return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
		}

		float GetShadowing() {
			vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

			// blocker search
			int blockerSampleCount = SHADOW_BLOCKER_SAMPLES;
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) blockerSampleCount = 1;
			float blockerDistance = FindBlockerDistance(pixelRadius, blockerSampleCount);
			if (blockerDistance < 0.0) return 1.0;

			// penumbra estimation
			float penumbraWidth = (shadowPos.z - blockerDistance) / blockerDistance;

			// percentage-close filtering
			pixelRadius *= min(penumbraWidth * 40.0, 1.0); // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

			int pcfSampleCount = POISSON_SAMPLES;
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;
			return 1.0 - GetShadowing_PCF(pixelRadius, pcfSampleCount);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			vec2 pixelRadius = GetShadowPixelRadius(SHADOW_PCF_SIZE);

			int sampleCount = POISSON_SAMPLES;
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;
			return 1.0 - GetShadowing_PCF(pixelRadius, sampleCount);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing() {
			float texDepth = SampleDepth(vec2(0.0));
			return step(shadowPos.z, texDepth);
		}
	#endif
#endif
