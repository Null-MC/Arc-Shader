const float[5] moonPhaseLevels = float[](0.1, 0.4, 0.7, 0.9, 1.0);

vec3 GetTransmittance(const in sampler3D tex, const in float height, const in float skyLightLevel) {
    vec3 uv;
    uv.x = saturate(skyLightLevel * 0.5 + 0.5);
    uv.y = saturate((height - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));
    uv.z = wetness;

    return textureLod(tex, uv, 0).rgb;
}

vec3 GetSunTransmittance(const in sampler3D tex, const in float height, const in float skyLightLevel) {
    return GetTransmittance(tex, height, skyLightLevel);
}

float GetSunLux() {
    return mix(SunLux, SunOvercastLux, rainStrength);
}

vec3 GetSunColor() {
    return blackbody(SUN_TEMP);
}

vec3 GetSunLuxColor() {
    return GetSunLux() * GetSunColor();
}

vec3 GetMoonTransmittance(const in sampler3D tex, const in float height, const in float skyLightLevel) {
    return GetTransmittance(tex, height, skyLightLevel);
}

float GetMoonLux() {
    return mix(MoonLux, MoonOvercastLux, rainStrength);
}

vec3 GetMoonColor() {
    return blackbody(MOON_TEMP);
}

vec3 GetMoonLuxColor() {
    return GetMoonLux() * GetMoonColor();
}

float GetMoonPhaseLevel() {
    return moonPhaseLevels[abs(moonPhase - 4)];
}
