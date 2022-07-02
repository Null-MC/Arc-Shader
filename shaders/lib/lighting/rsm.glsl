// vec3 GetShadowLocalPosition(const in vec2 uv) {
// 	float depth = texture2DLod(shadowtex1, uv, 0).r;
// 	vec3 clipPos = vec3(uv, depth) * 2.0 - 1.0;

// 	#if SHADOW_TYPE == 2
// 		clipPos = undistort(clipPos);
// 	#endif

// 	vec4 localPos = shadowModelViewInverse * (shadowProjectionInverse * vec4(clipPos, 1.0));
// 	return localPos.xyz / localPos.w;
// }

#if SHADOW_TYPE == 3
	vec3 GetNearestDepth(const in vec3 shadowViewPos, out ivec2 uv_out, out int cascade) {
		float depth = 1.0;
		vec2 pos_out = vec2(0.0);
		uv_out = ivec2(0);
		cascade = -1;

		float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

		for (int i = 0; i < 4; i++) {
			vec3 shadowPos = (matShadowProjections[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;

			// Ignore if outside cascade bounds
			if (shadowPos.x < 0.0 || shadowPos.x >= 1.0
			 || shadowPos.y < 0.0 || shadowPos.y >= 1.0) continue;

			vec2 shadowTilePos = GetShadowCascadeClipPos(i);
			ivec2 iuv = ivec2((shadowTilePos + 0.5 * shadowPos.xy) * shadowMapSize);

			//vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSizes[i]) * shadowPixelSize;
			
			//vec2 pixelOffset = blockOffset * pixelPerBlockScale;
			//float texDepth = SampleDepth(uv, vec2(0.0));
            float texDepth = texelFetch(shadowtex1, iuv, 0).r;

            if (texDepth < depth) {
				depth = texDepth;
				pos_out = shadowPos.xy;
				uv_out = iuv;
				cascade = i;
			}
		}

		return vec3(pos_out, depth);
	}
#endif

vec3 GetIndirectLighting_RSM(const in vec3 shadowViewPos, const in vec3 localPos, const in vec3 localNormal) {
	// Sum contributions of sampling locations.
	vec3 shading = vec3(0.0);

	#if SHADOW_TYPE == 3
		mat4 matShadowProjectionsInv[4];
		matShadowProjectionsInv[0] = inverse(matShadowProjections[0]);
		matShadowProjectionsInv[1] = inverse(matShadowProjections[1]);
		matShadowProjectionsInv[2] = inverse(matShadowProjections[2]);
		matShadowProjectionsInv[3] = inverse(matShadowProjections[3]);
	#else
		mat4 matShadowClipToLocal = shadowModelViewInverse * shadowProjectionInverse;
	#endif

	for (int i = 0; i < POISSON_SAMPLES; i++) {
		vec3 offsetShadowViewPos = shadowViewPos + vec3(poissonDisk[i] * RSM_FILTER_SIZE, 0.0);

		vec2 uv;
		ivec2 iuv;
		vec3 x_p;
		#if SHADOW_TYPE == 1
			vec4 clipPos = shadowProjection * vec4(offsetShadowViewPos, 1.0);
			//clipPos.xy /= clipPos.w;
			//clipPos.w = 1.0;

			uv = clipPos.xy * 0.5 + 0.5;
			iuv = ivec2(uv * shadowMapSize);
			clipPos.z = texelFetch(shadowtex1, iuv, 0).r * 2.0 - 1.0;
			vec4 _localPos = matShadowClipToLocal * clipPos;
			x_p = _localPos.xyz;// / _localPos.w;
		#elif SHADOW_TYPE == 2
			vec4 clipPos = shadowProjection * vec4(offsetShadowViewPos, 1.0);
			//clipPos.w = 1.0;

			uv = distort(clipPos.xyz).xy * 0.5 + 0.5;
			iuv = ivec2(uv * shadowMapSize);

			//clipPos.xy /= clipPos.w;

			clipPos.z = texelFetch(shadowtex1, iuv, 0).r * 4.0 - 2.0;
			//clipPos.z /= clipPos.w;
			//clipPos.w = 1.0;

			vec4 _localPos = matShadowClipToLocal * clipPos;
			x_p = _localPos.xyz;// / _localPos.w;
		#elif SHADOW_TYPE == 3
			//vec3 offsetShadowViewPos = shadowViewPos + vec3(poissonDisk[i] * diskScale, 0.0);

	        int cascade; // = GetCascadeSampleIndex(offsetShadowViewPos, uv);
	        vec3 clipPos = GetNearestDepth(offsetShadowViewPos, iuv, cascade) * 2.0 - 1.0;

	        //vec4 clipPos = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
			//clipPos.z = texture2DLod(shadowtex1, uv, 0).r * 2.0 - 1.0;

			// const float cascadePixelSize = 2.0 * shadowPixelSize;
			// vec2 uv = shadowUV + poissonDisk[i] * diskScale * cascadePixelSize;
			// int cascade = texture2DLod(shadowcolor1, uv * 0.5, 0).r;
			//vec2 cascadePos = GetShadowCascadeClipPos(cascade);
			//uv = cascadePos + 0.5 * uv;
			//iuv = ivec2(clipPos.xy * shadowMapSize);

			//return texture2DLod(shadowtex1, uv, 0).rrr;

			// if (cascade < 0) return vec3(0.0);
			// if (cascade == 0) return vec3(1.0, 0.0, 0.0);
			// if (cascade == 1) return vec3(0.0, 1.0, 0.0);
			// if (cascade == 2) return vec3(0.0, 0.0, 1.0);
			// if (cascade == 3) return vec3(1.0, 0.0, 1.0);
			// return vec3(1.0);

			//vec3 x_p = texture2DLod(shadowcolor1, uv, 0).xyz;
			x_p = (shadowModelViewInverse * (matShadowProjectionsInv[cascade] * vec4(clipPos, 1.0))).xyz;
		#endif

		//return localPos * 0.1;
		//return x_p * 0.1;

        uvec2 data = texelFetch(shadowcolor0, iuv, 0).rg;

		// Irradiance at current fragment w.r.t. pixel light at uv.
		vec3 r = localPos - x_p; // Difference vector.
		float d2 = dot(r, r); // Square distance.
		//return vec3(d2 * 0.01);
		//return r * 0.1;
		//return localPos * 0.1;

		vec3 n_p = RestoreNormalZ(unpackUnorm2x16(data.g));
		n_p = mat3(shadowModelViewInverse) * n_p;

        vec3 flux = unpackUnorm4x8(data.r).rgb;
        flux = RGBToLinear(flux);
        //return flux;

        float t = max(dot(n_p, r), 0.0) * max(dot(localNormal, -r), 0.0);
		//return n_p;

		vec3 E_p = flux * t;

		// Weighting contribution and normalizing.
		//float weight = poissonDisk[i].x * poissonDisk[i].x;
		float weight = dot(poissonDisk[i], poissonDisk[i]);
		E_p *= weight / (d2 * d2);

		// Accumulate
		shading += E_p;
	}

	// Modulate result with some intensity value.
	return shading * (1.0 / POISSON_SAMPLES) * RSM_INTENSITY;
}
