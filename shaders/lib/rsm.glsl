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

	#if SHADOW_TYPE != 3
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
	        int cascade;
	        vec3 clipPos = GetNearestDepth(offsetShadowViewPos, iuv, cascade);

	        vec3 shadowViewPos2 = offsetShadowViewPos;
	        shadowViewPos2.z = -clipPos.z * far * 3.0 + far;

			x_p = (shadowModelViewInverse * vec4(shadowViewPos2, 1.0)).xyz;
		#endif

        uvec2 data = texelFetch(shadowcolor0, iuv, 0).rg;

		// Irradiance at current fragment w.r.t. pixel light at uv.
		vec3 r = localPos - x_p; // Difference vector.
		float d2 = dot(r, r); // Square distance.

		vec3 n_p = RestoreNormalZ(unpackUnorm2x16(data.g));
		n_p = mat3(shadowModelViewInverse) * n_p;

        vec3 flux = unpackUnorm4x8(data.r).rgb;
        flux = RGBToLinear(flux);

        float t = max(dot(n_p, r), 0.0) * max(dot(localNormal, -r), 0.0);

		vec3 E_p = flux * t;

		// Weighting contribution and normalizing.
		//float weight = poissonDisk[i].x * poissonDisk[i].x;
		float weight = dot(poissonDisk[i], poissonDisk[i]);
		E_p *= weight / (d2 * d2);

		// Accumulate
		shading += E_p;
	}

	// Modulate result with some intensity value.
	return shading * (1.0 / POISSON_SAMPLES) * RSM_INTENSITY * RSM_FILTER_SIZE;
}
