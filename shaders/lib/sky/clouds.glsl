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

bool HasClouds(const in vec3 worldPos, const in vec3 localViewDir) {
	return step(worldPos.y, CLOUD_LEVEL) == step(0.0, localViewDir.y);
}

vec3 GetCloudPosition(const in vec3 worldPos, const in vec3 localViewDir) {
	return worldPos + (localViewDir / localViewDir.y) * (CLOUD_LEVEL - worldPos.y);
}

float GetCloudFactor(const in vec3 cloudPos, const in vec3 localViewDir, const in float lod) {
	float time = frameTimeCounter / 3.6;

	float d = GetCloudDensity(cloudPos.xz * 0.003, time * 0.01);
	d = saturate(d);

	d = pow(d, 1.0 - 0.6 * wetness);

	return d;
}

vec3 GetCloudColor(const in vec3 cloudPos, const in vec3 viewDir, const in vec2 skyLightLevels) {
	vec3 atmosPos = cloudPos - vec3(cameraPosition.x, SEA_LEVEL, cameraPosition.z);
	atmosPos *= (atmosphereRadiusMM - groundRadiusMM) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
	atmosPos.y = groundRadiusMM + clamp(atmosPos.y, 0.0, atmosphereRadiusMM - groundRadiusMM);

	//atmosPos.y = GetScaledSkyHeight(atmosPos.y);
    //float scaleY = (cameraPosition.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
    //return groundRadiusMM + saturate(scaleY) * (atmosphereRadiusMM - groundRadiusMM);

    vec3 sunDir = GetSunDir();
    vec3 moonDir = GetMoonDir();

    float sun_VoL = dot(viewDir, sunDir);
    float moon_VoL = dot(viewDir, moonDir);

    sunDir = mat3(gbufferModelViewInverse) * sunDir;
    moonDir = mat3(gbufferModelViewInverse) * moonDir;

    #if SHADER_PLATFORM == PLATFORM_IRIS
		vec3 sunTransmittance = getValFromTLUT(texSunTransmittance, atmosPos, sunDir);
		vec3 moonTransmittance = getValFromTLUT(texSunTransmittance, atmosPos, moonDir);
    #else
		#ifdef RENDER_DEFERRED
			vec3 sunTransmittance = getValFromTLUT(colortex0, atmosPos, sunDir);
			vec3 moonTransmittance = getValFromTLUT(colortex0, atmosPos, moonDir);
		#else
			vec3 sunTransmittance = getValFromTLUT(colortex9, atmosPos, sunDir);
			vec3 moonTransmittance = getValFromTLUT(colortex9, atmosPos, moonDir);
		#endif
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
	    vec3 ambient = 0.2 * (sunColor + moonColor);
	#else
	    vec3 ambient = 0.48 * (sunColor * max(skyLightLevels.x, 0.0) + moonColor * max(skyLightLevels.y, 0.0));
	#endif

    vec3 vl = sunColor * sunScatterF + moonColor * moonScatterF;// * max(skyLightLevels.x, 0.0); //+ moonColor * moonScatterF;

    return (ambient + vl) * CLOUD_COLOR * pow(1.0 - 0.9 * rainStrength, 2.0);
}
