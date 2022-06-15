#extension GL_ARB_texture_gather : enable

varying float cascadeSize[4];
flat varying int shadowTile;

const float tile_dist_bias_factor = 0.012288;

#ifdef RENDER_VERTEX
	void ApplyShadows(const in vec4 viewPos) {
		#ifndef RENDER_TEXTURED
			shadowTileColor = vec3(1.0);
		#endif

		if (geoNoL > 0.0) {
			// vertex is facing towards the sun
			mat4 matShadowProjection[4];
			PrepareCascadeMatrices(matShadowProjection);

			mat4 matShadowModelView = GetShadowModelViewMatrix();
			vec4 shadowViewPos = matShadowModelView * (gbufferModelViewInverse * viewPos);

			for (int i = 0; i < 4; i++) {
				shadowProjectionSize[i] = 2.0 / vec2(
					matShadowProjection[i][0].x,
					matShadowProjection[i][1].y);

				cascadeSize[i] = GetCascadeDistance(i);
				
				// convert to shadow screen space
				#ifdef RENDER_TEXTURED
					shadowPos[i] = (matShadowProjection[i] * shadowViewPos).xyz;
				#else
					shadowPos[i] = matShadowProjection[i] * shadowViewPos;
				#endif

				vec2 shadowTilePos = GetShadowTilePos(i);
				shadowPos[i].xyz = shadowPos[i].xyz * 0.5 + 0.5; // convert from -1 ~ +1 to 0 ~ 1
				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowTilePos; // scale and translate to quadrant
			}

			shadowTile = GetShadowTile(matShadowProjection);

			#if defined DEBUG_CASCADE_TINT && !defined RENDER_TEXTURED
				shadowTileColor = GetShadowTileColor(shadowTile);
			#endif
		}
		else {
			// vertex is facing away from the sun
			// mark that this vertex does not need to check the shadow map.
			shadowTile = -1;

			#ifdef RENDER_TEXTURED
				shadowPos[0] = vec3(0.0);
				shadowPos[1] = vec3(0.0);
				shadowPos[2] = vec3(0.0);
				shadowPos[3] = vec3(0.0);
			#else
				shadowPos[0] = vec4(0.0);
				shadowPos[1] = vec4(0.0);
				shadowPos[2] = vec4(0.0);
				shadowPos[3] = vec4(0.0);
			#endif
		}
	}
#endif

#ifdef RENDER_FRAG
	#define PCF_MAX_RADIUS 0.16

	const int pcf_sizes[4] = int[](4, 3, 2, 1);
	const int pcf_max = 4;

	float SampleDepth(const in vec2 offset, const in int tile) {
		#if SHADOW_COLORS == 0
			return texture2D(shadowtex0, shadowPos[tile].xy + offset).r;
		#else
			return texture2D(shadowtex1, shadowPos[tile].xy + offset).r;
		#endif
	}

	// float CompareDepth(const in vec2 offset, const in int tile) {
	// 	#if SHADOW_COLORS == 0
	// 		return shadow2D(shadowtex0, shadowPos[tile].xyz + offset, refZ).r;
	// 	#else
	// 		return shadow2D(shadowtex1, shadowPos[tile].xy + offset, refZ).r;
	// 	#endif
	// }

	// float SampleDepth4(const in vec2 offset, const in int tile) {
	// 	#if SHADOW_COLORS == 0
	// 		//for normal shadows, only consider the closest thing to the sun,
	// 		//regardless of whether or not it's opaque.
	// 		vec4 samples = textureGather(shadowtex0, shadowPos[tile].xy + offset);
	// 	#else
	// 		//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
	// 		vec4 samples = textureGather(shadowtex1, shadowPos[tile].xy + offset);
	// 	#endif

	// 	float result = samples[0];
	// 	for (int i = 1; i < 4; i++)
	// 		result = min(result, samples[i]);

	// 	return result;
	// }

	// float CompareDepth4(const in vec2 offset, const in float z, const in int tile) {
	// 	#if SHADOW_COLORS == 0
	// 		vec4 samples = textureGather(shadowtex0, shadowPos[tile].xy + offset, shadowPos[tile].z);
	// 	#else
	// 		vec4 samples = textureGather(shadowtex1, shadowPos[tile].xy + offset, shadowPos[tile].z);
	// 	#endif

	// 	float result = samples[0];
	// 	for (int i = 1; i < 4; i++)
	// 		if (samples[i] < z) return 1.0;

	// 	return 0.0;
	// }

	float GetNearestDepth(const in vec2 blockOffset, out int tile) {
		float depth = 1.0;
		tile = -1;

		float shadowResScale = tile_dist_bias_factor * shadowPixelSize;
		float texSize = shadowMapResolution * 0.5;

		float texDepth;
		for (int i = 0; i < 4; i++) {
			// Ignore if outside tile bounds
			vec2 shadowTilePos = GetShadowTilePos(i);
			if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
			if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

			vec2 pixelPerBlockScale = (texSize / shadowProjectionSize[i]) * shadowPixelSize;
			
			vec2 pixelOffset = blockOffset * pixelPerBlockScale;
			texDepth = SampleDepth(pixelOffset, i);

			if (i != shadowTile) {
				vec2 ratio = (shadowProjectionSize[shadowTile] / shadowProjectionSize[i]) * shadowPixelSize;

				vec4 samples;
				samples.x = SampleDepth(pixelOffset + vec2(-1.0, 0.0)*ratio, i);
				samples.y = SampleDepth(pixelOffset + vec2( 1.0, 0.0)*ratio, i);
				samples.z = SampleDepth(pixelOffset + vec2( 0.0,-1.0)*ratio, i);
				samples.w = SampleDepth(pixelOffset + vec2( 0.0, 1.0)*ratio, i);

				texDepth = min(texDepth, samples.x);
				texDepth = min(texDepth, samples.y);
				texDepth = min(texDepth, samples.z);
				texDepth = min(texDepth, samples.w);
			}

			float bias = cascadeSize[shadowTile] * shadowResScale * SHADOW_BIAS_SCALE;
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

	#if SHADOW_COLORS == 1
		vec3 GetShadowColor() {
			int tile = -1;
			float depthLast = 1.0;
			for (int i = 0; i < 4; i++) {
				vec2 shadowTilePos = GetShadowTilePos(i);
				if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
				if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
				//perform a 2nd check to see if there's anything translucent between us and the sun.
				float depth = texture2D(shadowtex0, shadowPos[i].xy).r;
				if (depth + EPSILON < 1.0 && depth < shadowPos[i].z && depth < depthLast) {
					depthLast = depth;
					tile = i;
				}
			}

			if (tile < 0) return vec3(1.0);

			//surface has translucent object between it and the sun. modify its color.
			//if the block light is high, modify the color less.
			vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos[tile].xy);
			vec3 color = RGBToLinear(shadowLightColor.rgb);

			//make colors more intense when the shadow light color is more opaque.
			return mix(vec3(1.0), color, shadowLightColor.a);
		}
	#endif

	#if SHADOW_FILTER != 0
		float GetShadowing_PCF(const in float blockRadius, const in int sampleCount) {
			int tile;
			float texDepth;
			float shadow = 0.0;
			for (int i = 0; i < sampleCount; i++) {
				vec2 blockOffset = poissonDisk[i] * blockRadius;
				float texDepth = GetNearestDepth(blockOffset, tile);
				shadow += step(texDepth + EPSILON, shadowPos[tile].z);
			}

			if (sampleCount == 1) return shadow;

			#if SHADOW_FILTER == 1
				float f = 1.0 - max(geoNoL, 0.0);
				f = clamp(shadow / sampleCount - 0.8*f, 0.0, 1.0) * (1.0 + 1.0 * f);
				return clamp(f, 0.0, 1.0);
			#else
				return expStep(shadow / sampleCount);
			#endif
		}
	#endif

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		#define SHADOW_BLOCKER_SAMPLES 12

		float FindBlockerDistance(const in float blockRadius, const in int sampleCount) {
			// NOTE: This optimization doesn't really help here rn since the search radius is fixed
			//if (blockRadius <= shadowPixelSize) sampleCount = 1;

			//float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
			//float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
			float avgBlockerDistance = 0;
			int blockers = 0;

			int tile;
			for (int i = 0; i < sampleCount; i++) {
				vec2 blockOffset = poissonDisk[i] * blockRadius;
				float texDepth = GetNearestDepth(blockOffset, tile);

				if (texDepth < shadowPos[tile].z) { // - directionalLightShadowMapBias
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

			if (blockers == sampleCount) return 1.0;
			return blockers > 0 ? avgBlockerDistance / blockers : 0.0;
		}

		float GetShadowing() {
			// blocker search
			int blockerSampleCount = SHADOW_BLOCKER_SAMPLES;
			float blockerDistance = FindBlockerDistance(SHADOW_PCF_SIZE, blockerSampleCount);
			if (blockerDistance <= 0.0) return 1.0;
			if (blockerDistance >= 1.0) return 0.0;

			// penumbra estimation
			float penumbraWidth = (shadowPos[shadowTile].z - blockerDistance) / blockerDistance;

			// percentage-close filtering
			float blockRadius = clamp(penumbraWidth * 75.0, 0.0, 1.0) * SHADOW_PCF_SIZE; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

			int pcfSampleCount = POISSON_SAMPLES;

			float texSize = shadowMapResolution * 0.5;
			vec2 pixelRadius = blockRadius * (texSize / shadowProjectionSize[shadowTile]) * shadowPixelSize;
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

			return 1.0 - GetShadowing_PCF(blockRadius, pcfSampleCount);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing() {
			//float blockRadius = SHADOW_PCF_SIZE;

			float texSize = shadowMapResolution * 0.5;
			vec2 pixelRadius = SHADOW_PCF_SIZE * (texSize / shadowProjectionSize[shadowTile]) * shadowPixelSize;

			int sampleCount = POISSON_SAMPLES;
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

			return 1.0 - GetShadowing_PCF(SHADOW_PCF_SIZE, sampleCount);
		}
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing() {
			int tile;
			float texDepth = GetNearestDepth(vec2(0.0), tile);
			return step(1.0, texDepth + EPSILON);
		}
	#endif
#endif
