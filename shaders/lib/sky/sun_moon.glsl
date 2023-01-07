const float[5] moonPhaseLevels = float[](0.1, 0.4, 0.7, 0.9, 1.0);


#if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
    // by BuilderBoy
    vec3 GetFixedSunPosition() {
        const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

        float ang = fract(worldTime / 24000.0 - 0.25);
        ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * (2.0*PI); //0-2pi, rolls over from 2pi to 0 at noon.

        return mat3(gbufferModelView) * vec3(-sin(ang), cos(ang) * sunRotationData);
    }
#endif

vec3 GetSunDir() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return GetFixedSunPosition();
    #else
        return normalize(sunPosition);
    #endif
}

vec3 GetMoonDir() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return -GetFixedSunPosition();
    #else
        return normalize(moonPosition);
    #endif
}

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
