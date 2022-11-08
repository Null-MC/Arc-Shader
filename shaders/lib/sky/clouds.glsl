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

	float cloudF = 0.0;
	cloudF += textureLod(noisetex, p1 * 0.0001, 0).r;
	cloudF += textureLod(noisetex, p2 * 0.0004, 0).r;
	cloudF += 0.5 * textureLod(noisetex, p3 * 0.0016, 0).r;
	cloudF += 0.1 * textureLod(noisetex, p4 * 0.0064, 0).r;

    //float cloudPow = mix(CLOUD_POW_CLEAR, CLOUD_POW_RAIN, rainStrength);
    //cloudF = pow(cloudF, cloudPow);
    cloudF = pow(cloudF, mix(0.8, 0.3, rainStrength));
    cloudF = smoothstep(0.0, 1.0, cloudF);

	return cloudF;
}
