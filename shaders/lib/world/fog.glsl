const vec3 caveFogColor = vec3(0.02);


float GetCaveFogFactor(const in float skyLightLevel) {
    return max(0.96 - 3.0 * skyLightLevel, 0.0);
}

float GetFogFactor(const in vec3 viewPos, const in float skyLightLevel) {
	//vec3 fogPos = viewPos;
	//if (fogShape == 1) fogPos.z = 0.0;
    float _start = fogStart;
    float _end = fogEnd;

    float caveFogLevel = GetCaveFogFactor(skyLightLevel);
    _start *= (1.0 - caveFogLevel);

	return clamp((length(viewPos) - _start) / (_end - _start), 0.0, 1.0);
}

void ApplyFog(inout vec3 color, const in vec3 viewPos, const in float skyLightLevel) {
    #ifdef SHADOW_ENABLED
        vec3 viewDir = normalize(viewPos);
        vec3 atmosphereColor = GetSkyColor(viewDir);
    #else
        vec3 atmosphereColor = RGBToLinear(fogColor);
    #endif

    float caveFogLevel = GetCaveFogFactor(skyLightLevel);
    atmosphereColor = mix(atmosphereColor, caveFogColor, caveFogLevel);

    float fogFactor = GetFogFactor(viewPos, skyLightLevel);
    color = mix(color, atmosphereColor, fogFactor);
}

void ApplyFog(inout vec4 color, const in vec3 viewPos, const in float skyLightLevel, const in float alphaTestRef) {
    #ifdef SHADOW_ENABLED
        vec3 viewDir = normalize(viewPos);
        vec3 atmosphereColor = GetSkyColor(viewDir);
    #else
        vec3 atmosphereColor = RGBToLinear(fogColor);
    #endif

    float caveFogLevel = GetCaveFogFactor(skyLightLevel);
    atmosphereColor = mix(atmosphereColor, caveFogColor, caveFogLevel);

    float fogFactor = GetFogFactor(viewPos, skyLightLevel);
    color.rgb = mix(color.rgb, atmosphereColor, fogFactor);

    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogFactor);
}
