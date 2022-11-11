vec3 GetSunTransmittance(const in sampler2D tex, const in float height, const in float skyLightLevel) {
    vec2 uv;
    uv.x = saturate(skyLightLevel * 0.5 + 0.5);
    uv.y = saturate((height - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));
    return textureLod(tex, uv, 0).rgb;
}

float GetSunLux() {
    return mix(SunLux, SunOvercastLux, rainStrength);
}

vec3 GetSunLuxColor() {
    return GetSunLux() * blackbody(SUN_TEMP);
}
