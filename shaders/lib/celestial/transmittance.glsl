const float[5] moonPhaseLevels = float[](0.1, 0.4, 0.7, 0.9, 1.0);

vec3 GetTransmittance(const in sampler3D tex, const in float elevation, const in float skyLightLevel) {
    vec3 uv;
    uv.x = saturate(skyLightLevel * 0.5 + 0.5);
    uv.y = saturate((elevation - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM));
    uv.z = wetness;

    return textureLod(tex, uv, 0).rgb;
}

vec3 GetWorldTransmittance(const in sampler3D tex, const in float worldY, const in float skyLightLevel) {
    float elevation = GetScaledSkyHeight(worldY);
    return GetTransmittance(tex, elevation, skyLightLevel);
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
