const vec3 sunColor = 1.4 * vec3(1.0, 0.9, 0.8);
const vec3 moonColor = 0.1 * vec3(0.5, 0.6, 1.0);


vec3 GetSkyLightColor() {
	vec3 upDir = normalize(upPosition);

    vec3 sunLightDir = normalize(sunPosition);
    float sunLightStrength = max(dot(upDir, sunLightDir), 0.0);
    vec3 sunLight = sunColor * sunLightStrength;

    vec3 moonLightDir = normalize(moonPosition);
    float moonLightStrength = max(dot(upDir, moonLightDir), 0.0);
    vec3 moonLight = moonColor * moonLightStrength;

    return sunLight + moonLight;
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
