float GetDirectionalWetness(const in vec3 normal, const in float skyLight) {
    vec3 viewUpDir = normalize(upPosition);
    float wetness_NoU = dot(normal, viewUpDir) * 0.4 + 0.6;
    float wetness_skyLight = max((skyLight - (14.0/16.0)) * 16.0, 0.0);
    return wetness * wetness_skyLight * wetness_NoU;
}

float GetSurfaceWetness(const in float wetness, const in float porosity) {
    return max(wetness - 0.75*pow2(porosity), 0.0);
}

float GetWetnessDarkening(const in float wetness, const in float porosity) {
    return 1.0 - 0.58 * wetness * porosity;
}
