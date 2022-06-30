// vec3 GetShadowLocalPosition(const in vec2 uv) {
// 	float depth = texture2DLod(shadowtex1, uv, 0).r;
// 	vec3 clipPos = vec3(uv, depth) * 2.0 - 1.0;

// 	#if SHADOW_TYPE == 2
// 		clipPos = undistort(clipPos);
// 	#endif

// 	vec4 localPos = shadowModelViewInverse * (shadowProjectionInverse * vec4(clipPos, 1.0));
// 	return localPos.xyz / localPos.w;
// }

vec3 GetIndirectLighting_RSM(const in vec2 shadowCoord, const in vec3 localPos, const in vec3 localNormal) {
	float diskScale = RSM_R_MAX;

	#if SHADOW_TYPE == 2
		diskScale *= max(1.0 - cubeLength(shadowCoord), 0.0);
	#endif

	vec2 shadowUV = shadowCoord * 0.5 + 0.5;

	int sampleCount = POISSON_SAMPLES;
	if (diskScale < 1.0) sampleCount = 1;
	diskScale *= shadowPixelSize;

	// Sum contributions of sampling locations.
	vec3 shading = vec3(0.0);
	for (int i = 0; i < sampleCount; i++) {
		vec2 uv = shadowUV + poissonDisk[i] * diskScale;
        uvec2 data = texture2DLod(shadowcolor0, uv, 0).rg;

		// Position (x_p) and normal (n_p) are in world coordinates too.
		//vec3 x_p = GetShadowLocalPosition(uv);
		vec3 x_p = texture2DLod(shadowcolor1, uv, 0).xyz;

		// Irradiance at current fragment w.r.t. pixel light at uv.
		vec3 r = localPos - x_p; // Difference vector.
		float d2 = dot(r, r); // Square distance.

		vec3 n_p = RestoreNormalZ(unpackUnorm2x16(data.g));
		n_p = mat3(shadowModelViewInverse) * n_p;

        vec3 flux = unpackUnorm4x8(data.r).rgb;
        flux = RGBToLinear(flux);

		vec3 E_p = flux * (max(dot(n_p, r), 0.0) * max(dot(localNormal, -r), 0.0));

		// Weighting contribution and normalizing.
		//float weight = poissonDisk[i].x * poissonDisk[i].x;
		float weight = dot(poissonDisk[i], poissonDisk[i]);
		E_p *= weight / (d2 * d2);

		// Accumulate
		shading += E_p;
	}

	// Modulate result with some intensity value.
	return shading * (1.0 / sampleCount) * RSM_INTENSITY;
}
