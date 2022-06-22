float GetFogFactor(const in vec3 viewPos) {
	//vec3 fogPos = viewPos;
	//if (fogShape == 1) fogPos.z = 0.0;
	return clamp((length(viewPos) - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
}

void ApplyFog(inout vec3 color, const in vec3 viewPos) {
    vec3 fogCol = RGBToLinear(fogColor);
    float fogF = GetFogFactor(viewPos);

    color = mix(color, fogCol, fogF);
}

void ApplyFog(inout vec4 color, const in vec3 viewPos, const in float alphaTestRef) {
    vec3 fogCol = RGBToLinear(fogColor);
    float fogF = GetFogFactor(viewPos);

    color.rgb = mix(color.rgb, fogCol, fogF);

    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogF);
}
