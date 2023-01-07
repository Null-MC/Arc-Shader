const mat2 cloud_m = mat2(1.6, 1.2, -1.2, 1.6);

vec2 Cloud_hash22(const in vec2 pos) {
	vec2 p = vec2(
		dot(pos, vec2(127.1, 311.7)),
		dot(pos, vec2(269.5, 183.3)));

	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float CloudNoise(const in vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;

	vec2 i = floor(p + (p.x+p.y) * K1);
    vec2 a = p - i + (i.x+i.y) * K2;
    vec2 o = (a.x > a.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec2 b = a - o + K2;
	vec2 c = a - 1.0 + 2.0*K2;
    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);

	vec3 n = pow4(h) * vec3(
		dot(a, Cloud_hash22(i + 0.0)),
		dot(b, Cloud_hash22(i + o)),
		dot(c, Cloud_hash22(i + 1.0)));

    return dot(n, vec3(70.0));	
}

float fbm(vec2 n) {
	float amplitude = 0.1;
	float total = 0.0;

	for (int i = 0; i < 7; i++) {
		total += CloudNoise(n) * amplitude;
		n = cloud_m * n;
		amplitude *= 0.4;
	}

	return total;
}

float GetCloudDensity(const in vec2 pos, const in float time) {
	float q = fbm(pos * 0.5);

    vec2 uv = pos - (q - time);

	float f = 0.0;
    float weight = 0.7;
    for (int i = 0; i < 8; i++) {
		f += weight * CloudNoise(uv);
        uv = cloud_m * uv + time;
		weight *= 0.6;
    }

    return f;
}

float GetCloudFactor(const in vec3 localPos, const in vec3 localViewDir, const in float lod) {
	if (localPos.y < CLOUD_LEVEL) {
		if (localViewDir.y <= 0.0) return 0.0;
	}
	else {
		if (localViewDir.y >= 0.0) return 0.0;
	}

	vec2 pos = localPos.xz + (localViewDir.xz / localViewDir.y) * (CLOUD_LEVEL - localPos.y);

	float time = frameTimeCounter / 3.6;
	// vec2 p1 = pos + vec2(2.0, 8.0) * time;
	// vec2 p2 = pos + vec2(4.0, 8.0) * time;
	// vec2 p3 = pos + vec2(8.0, 4.0) * time;
	// vec2 p4 = pos + vec2(4.0, 4.0) * time;

    // const float cloudScale = 0.00002;
	// float t1 = textureLod(noisetex, p1 * cloudScale *  8, lod).r;
	// float t2 = textureLod(noisetex, p2 * cloudScale * 16, lod).r;
	// float t3 = textureLod(noisetex, p3 * cloudScale * 32, lod).r;
	// float t4 = textureLod(noisetex, p4 * cloudScale * 64, lod).r;

	// float cloudF = 0.0;
	// float p;

	// // big clouds
	// p = mix(0.5, 0.3, wetness);
	// cloudF = max(cloudF, pow(max(t1 * t2 - 0.08, 0.0), p));

	// // medium clouds
	// p = mix(0.5, 0.3, wetness);

	// // tiny clouds
	// p = mix(0.5, 0.3, wetness);

	float d = GetCloudDensity(pos * 0.003, time * 0.01);
	d = saturate(d);

	d = pow(d, 1.0 - 0.6 * wetness);

	return d;
}

vec3 GetCloudColor(const in vec2 skyLightLevels, const in float sun_VoL, const in float moon_VoL) {
	#ifdef RENDER_DEFERRED
		vec3 sunTransmittance = GetSunTransmittance(colortex7, CLOUD_LEVEL, skyLightLevels.x);
		vec3 moonTransmittance = GetMoonTransmittance(colortex7, CLOUD_LEVEL, skyLightLevels.y);
	#else
		vec3 sunTransmittance = GetSunTransmittance(colortex9, CLOUD_LEVEL, skyLightLevels.x);
		vec3 moonTransmittance = GetMoonTransmittance(colortex9, CLOUD_LEVEL, skyLightLevels.y);
	#endif

    float sunScatterF = mix(
        ComputeVolumetricScattering(sun_VoL, -0.24),
        ComputeVolumetricScattering(sun_VoL, 0.86),
        0.3);

    float moonScatterF = mix(
        ComputeVolumetricScattering(moon_VoL, -0.24),
        ComputeVolumetricScattering(moon_VoL, 0.86),
        0.3);

    vec3 sunColor = sunTransmittance * GetSunLuxColor();// * smoothstep(-0.06, 0.6, skyLightLevels.x);
    //cloudSunColor *= smoothstep(-0.08, 1.0, skyLightLevels.x);

    vec3 moonColor = moonTransmittance * GetMoonLuxColor() * GetMoonPhaseLevel();// * smoothstep(-0.06, 0.6, skyLightLevels.y);
    //cloudSunColor *= smoothstep(-0.08, 1.0, skyLightLevels.y);

    #if ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
	    vec3 ambient = 0.48 * (sunColor + moonColor);
	#else
	    vec3 ambient = 0.48 * (sunColor * max(skyLightLevels.x, 0.0) + moonColor * max(skyLightLevels.y, 0.0));
	#endif

    vec3 vl = sunColor * sunScatterF + moonColor * moonScatterF;// * max(skyLightLevels.x, 0.0); //+ moonColor * moonScatterF;

    return (ambient + vl) * CLOUD_COLOR * pow(1.0 - 0.9 * rainStrength, 2.0);
}
