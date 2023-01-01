float GetCloudFactor(const in vec3 localPos, const in vec3 localViewDir, const in float lod) {
	if (localPos.y < CLOUD_LEVEL) {
		if (localViewDir.y <= 0.0) return 0.0;
	}
	else {
		if (localViewDir.y >= 0.0) return 0.0;
	}

	vec2 pos = localPos.xz + (localViewDir.xz / localViewDir.y) * (CLOUD_LEVEL - localPos.y);

	float time = frameTimeCounter / 3.6;
	vec2 p1 = pos + vec2(2.0, 8.0) * time;
	vec2 p2 = pos + vec2(4.0, 8.0) * time;
	vec2 p3 = pos + vec2(8.0, 4.0) * time;
	vec2 p4 = pos + vec2(4.0, 4.0) * time;

	float cloudF = 0.0;
	cloudF += 1.0 * textureLod(noisetex, p1 * 0.0001, lod).r;
	cloudF -= 0.3 * textureLod(noisetex, p2 * 0.0004, lod).r;
	cloudF += 0.6 * textureLod(noisetex, p3 * 0.0016, lod).r;
	cloudF -= 0.1 * textureLod(noisetex, p4 * 0.0064, lod).r;

	cloudF = saturate(cloudF);

    //cloudF = pow(cloudF, mix(1.0, 0.5, wetness));
    cloudF = pow(cloudF, 0.5);

    float cloudMin = mix(0.50, 0.20, wetness);
    float cloudMax = mix(0.80, 0.90, wetness);
	cloudF = smoothstep(cloudMin, cloudMax, cloudF);

	return cloudF;
}

vec3 GetCloudColor(const in vec2 skyLightLevels, const in float sun_VoL) {
	#ifdef RENDER_DEFERRED
		vec3 sunTransmittance = GetSunTransmittance(colortex7, CLOUD_LEVEL, skyLightLevels.x);
		vec3 moonTransmittance = GetMoonTransmittance(colortex7, CLOUD_LEVEL, skyLightLevels.y);
	#else
		vec3 sunTransmittance = GetSunTransmittance(colortex9, CLOUD_LEVEL, skyLightLevels.x);
		vec3 moonTransmittance = GetMoonTransmittance(colortex9, CLOUD_LEVEL, skyLightLevels.y);
	#endif

    //float sun_VoL = dot(viewDir, sunDir);
    float sunScatterF = mix(
        ComputeVolumetricScattering(sun_VoL, -0.26),
        ComputeVolumetricScattering(sun_VoL, 0.86),
        0.2);

    vec3 sunColor = sunTransmittance * GetSunLuxColor();// * smoothstep(-0.06, 0.6, skyLightLevels.x);
    //cloudSunColor *= smoothstep(-0.08, 1.0, skyLightLevels.x);

    vec3 moonColor = moonTransmittance * GetMoonLuxColor() * GetMoonPhaseLevel();// * smoothstep(-0.06, 0.6, skyLightLevels.y);
    //cloudSunColor *= smoothstep(-0.08, 1.0, skyLightLevels.y);

    vec3 ambient = 0.2 * (sunColor + moonColor) * pow(1.0 - rainStrength, 2.0) * CLOUD_COLOR;

    vec3 vl = sunColor * sunScatterF; //+ moonColor * moonScatterF;

    return ambient + vl;
}
