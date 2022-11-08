float GetCloudFactor(const in vec3 localPos, const in vec3 localViewDir) {
	if (localPos.y < CLOUD_PLANE_Y_LEVEL) {
		if (localViewDir.y <= 0.0) return 0.0;
	}
	else {
		if (localViewDir.y >= 0.0) return 0.0;
	}

	vec2 pos = localPos.xz + (localViewDir.xz / localViewDir.y) * (CLOUD_PLANE_Y_LEVEL - localPos.y);

	pos += vec2(2.0, 8.0) * (frameTimeCounter / 3.6);

	float cloudF = textureLod(noisetex, pos * 0.001, 0).r;

    //float cloudPow = mix(CLOUD_POW_CLEAR, CLOUD_POW_RAIN, rainStrength);
    //cloudF = pow(cloudF, cloudPow);
    cloudF = pow(cloudF, mix(0.8, 0.3, rainStrength));
    cloudF = smoothstep(0.0, 1.0, cloudF);

	return cloudF;
}
