#ifndef RENDER_SKYBASIC
	// returns: x:sun y:moon
	vec2 GetSkyLightIntensity() {
		vec3 upDir = normalize(upPosition);

	    vec3 sunLightDir = normalize(sunPosition);
	    float sunLightStrength = max(dot(upDir, sunLightDir), 0.0);
	    sunLightStrength = pow(sunLightStrength, 0.3);

	    vec3 moonLightDir = normalize(moonPosition);
	    float moonLightStrength = max(dot(upDir, moonLightDir), 0.0);
	    moonLightStrength = pow(moonLightStrength, 0.3);

	    vec2 skyLightIntensity = vec2(
	    	sunLightStrength * sunIntensity,
	    	moonLightStrength * moonIntensity);

	    skyLightIntensity *= 1.0 - rainStrength * (1.0 - RAIN_DARKNESS);

	    return skyLightIntensity;
	}

	vec3 GetSkyLightColor(const in vec2 skyLightIntensity) {
	    return sunColor * skyLightIntensity.x + moonColor * skyLightIntensity.y;
	}

	vec3 GetSkyLightColor() {
		return GetSkyLightColor(GetSkyLightIntensity());
	}
#endif

#ifdef RENDER_FRAG
	float GetSkyFog(float x, float w) {
		return w / (x * x + w);
	}

	vec3 GetSkyColor(const in vec3 viewDir) {
		vec3 skyColorLinear = RGBToLinear(skyColor);
		vec3 fogColorLinear = RGBToLinear(fogColor);

		vec3 upDir = normalize(upPosition); //gbufferModelView[1].xyz
		float VoUm = max(dot(viewDir, upDir), 0.0);
		return mix(skyColorLinear, fogColorLinear, GetSkyFog(VoUm, 0.25));
	}
#endif
