float GetCloudFactor(const in vec3 localPos, const in vec3 localViewDir) {
	if (localPos.y < CLOUD_PLANE_Y_LEVEL) {
		if (localViewDir.y <= 0.0) return 0.0;
	}
	else {
		if (localViewDir.y >= 0.0) return 0.0;
	}

	vec2 pos = localPos.xz + (localViewDir.xz / localViewDir.y) * (CLOUD_PLANE_Y_LEVEL - localPos.y);

	float time = frameTimeCounter / 3.6;
	vec2 p1 = pos + vec2(2.0, 8.0) * time;
	vec2 p2 = pos + vec2(4.0, 8.0) * time;
	vec2 p3 = pos + vec2(8.0, 4.0) * time;
	vec2 p4 = pos + vec2(4.0, 4.0) * time;

	float threshold = mix(0.18, 0.03, wetness);

	float cloudF = 0.0;
	cloudF += 1.000 * textureLod(noisetex, p1 * 0.0001, 0).r - 1.000*threshold;
	cloudF += 0.500 * textureLod(noisetex, p2 * 0.0004, 0).r - 0.500*threshold;
	cloudF += 0.250 * textureLod(noisetex, p3 * 0.0016, 0).r - 0.250*threshold;
	cloudF += 0.125 * textureLod(noisetex, p4 * 0.0064, 0).r - 0.125*threshold;

	cloudF = saturate(cloudF);
    //float cloudPow = mix(CLOUD_POW_CLEAR, CLOUD_POW_RAIN, rainStrength);
    //cloudF = pow(cloudF, cloudPow);
    cloudF = pow(cloudF, mix(0.8, 0.2, wetness));
    //cloudF = smoothstep(0.0, 1.0, cloudF);

	return cloudF;
}

vec3 GetCloudColor(const in vec2 skyLightLevels) {
	#ifdef RENDER_DEFERRED
		vec3 sunTransmittance = GetSunTransmittance(colortex7, CLOUD_PLANE_Y_LEVEL, skyLightLevels.x);
	#else
		vec3 sunTransmittance = GetSunTransmittance(colortex9, CLOUD_PLANE_Y_LEVEL, skyLightLevels.x);
	#endif

    vec3 cloudColor = sunTransmittance * GetSunLux();
    cloudColor *= vec3(0.248, 0.225, 0.273);
    cloudColor *= 1.0 - wetness;

    float lightLevel = saturate(0.08 + 0.92 * skyLightLevels.x);
    cloudColor *= smoothstep(0.0, 1.0, lightLevel);

    return cloudColor;
}
