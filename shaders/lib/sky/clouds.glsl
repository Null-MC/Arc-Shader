float GetCloudFactor(const in vec3 localPos, const in vec3 localViewDir) {
	if (localPos.y < CLOUD_Y_LEVEL) {
		if (localViewDir.y <= 0.0) return 0.0;
	}
	else {
		if (localViewDir.y >= 0.0) return 0.0;
	}

	vec2 pos = localPos.xz + (localViewDir.xz / localViewDir.y) * (CLOUD_Y_LEVEL - localPos.y);

	float time = frameTimeCounter / 3.6;
	vec2 p1 = pos + vec2(2.0, 8.0) * time;
	vec2 p2 = pos + vec2(4.0, 8.0) * time;
	vec2 p3 = pos + vec2(8.0, 4.0) * time;
	vec2 p4 = pos + vec2(4.0, 4.0) * time;

	float cloudF = 0.0;
	cloudF += 1.0 * textureLod(noisetex, p1 * 0.0001, 0).r;
	cloudF -= 0.3 * textureLod(noisetex, p2 * 0.0004, 0).r;
	cloudF += 0.6 * textureLod(noisetex, p3 * 0.0016, 0).r;
	cloudF -= 0.1 * textureLod(noisetex, p4 * 0.0064, 0).r;

	cloudF = saturate(cloudF);

    //cloudF = pow(cloudF, mix(1.0, 0.5, wetness));
    cloudF = pow(cloudF, 0.5);

    float cloudMin = mix(0.50, 0.01, wetness);
    float cloudMax = mix(0.80, 0.90, wetness);
	cloudF = smoothstep(cloudMin, cloudMax, cloudF);

	return cloudF;
}

vec3 GetCloudColor(const in vec2 skyLightLevels) {
    #if SHADER_PLATFORM == PLATFORM_IRIS
        vec3 sunTransmittance = GetSunTransmittance(texSunTransmission, CLOUD_Y_LEVEL, skyLightLevels.x);
        vec3 moonTransmittance = GetMoonTransmittance(texSunTransmission, CLOUD_Y_LEVEL, skyLightLevels.y);
    #else
		#ifdef RENDER_DEFERRED
			vec3 sunTransmittance = GetSunTransmittance(colortex7, CLOUD_Y_LEVEL, skyLightLevels.x);
			vec3 moonTransmittance = GetMoonTransmittance(colortex7, CLOUD_Y_LEVEL, skyLightLevels.y);
		#else
			vec3 sunTransmittance = GetSunTransmittance(colortex9, CLOUD_Y_LEVEL, skyLightLevels.x);
			vec3 moonTransmittance = GetMoonTransmittance(colortex9, CLOUD_Y_LEVEL, skyLightLevels.y);
		#endif
	#endif

    vec3 cloudSunColor = sunTransmittance * GetSunLuxColor() * smoothstep(-0.06, 0.6, skyLightLevels.x);
    //cloudSunColor *= smoothstep(-0.08, 1.0, skyLightLevels.x);

    vec3 cloudMoonColor = moonTransmittance * GetMoonLuxColor() * GetMoonPhaseLevel() * smoothstep(-0.06, 0.6, skyLightLevels.y);
    //cloudSunColor *= smoothstep(-0.08, 1.0, skyLightLevels.y);

    return (cloudSunColor + cloudMoonColor) * pow(1.0 - rainStrength, 2.0) * CLOUD_COLOR;
}
