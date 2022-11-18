float GetDirectionalWetness(const in vec3 normal, const in float skyLight) {
    vec3 viewUpDir = normalize(upPosition);
    float wetness_NoU = dot(normal, viewUpDir) * 0.5 + 0.5;
    float wetness_skyLight = saturate(8.0 * (0.96875 - skyLight));// + (1.0 - occlusion);
    return saturate(wetness * smoothstep(-0.2, 1.0, wetness_NoU) - wetness_skyLight);
}

float GetSurfaceWetness(const in float wetness, const in float porosity) {
    return saturate(2.0*wetness - porosity);
}

vec3 WetnessDarkenSurface(const in vec3 albedo, const in float porosity, const in float wetness) {
    float f = wetness * porosity;
    return pow(albedo, vec3(1.0 + f)) * saturate(1.0 - f * POROSITY_DARKENING);
}
