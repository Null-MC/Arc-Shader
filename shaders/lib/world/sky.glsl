const float sunIntensity = 10.0;
const float moonIntensity = 0.1;
const vec3 sunColor = vec3(1.0, 0.9, 0.8);
const vec3 moonColor = vec3(0.5, 0.6, 1.0);


vec2 GetSkyLightIntensity() {
	vec3 upDir = normalize(upPosition);

    vec3 sunLightDir = normalize(sunPosition);
    float sunLightStrength = max(dot(upDir, sunLightDir), 0.0);

    vec3 moonLightDir = normalize(moonPosition);
    float moonLightStrength = max(dot(upDir, moonLightDir), 0.0);

    return vec2(sunLightStrength * sunIntensity, moonLightStrength * moonIntensity);
}

vec3 GetSkyLightColor(const in vec2 skyLightIntensity) {
    return sunColor * skyLightIntensity.x + moonColor * skyLightIntensity.y;
}

vec3 GetSkyLightColor() {
	return GetSkyLightColor(GetSkyLightIntensity());
}

#ifdef RENDER_FRAG
    vec3 GetSkyAmbientColor(const in vec3 normal) {
		vec3 upDir = normalize(upPosition);

	    vec3 sunLightDir = normalize(sunPosition);
	    float sunLightStrength = max(dot(upDir, sunLightDir), 0.0);
	    float sunLightNormal = max(dot(normal, sunLightDir), 0.0);
	    vec3 sunLight = sunColor * sunLightStrength * sunLightNormal;

	    vec3 moonLightDir = normalize(moonPosition);
	    float moonLightStrength = max(dot(upDir, moonLightDir), 0.0);
	    float moonLightNormal = max(dot(normal, sunLightDir), 0.0);
	    vec3 moonLight = moonColor * moonLightStrength * moonLightNormal;

	    return skyColor + 0.2 * sunLight + 0.6 * moonLight;
    }
#endif
