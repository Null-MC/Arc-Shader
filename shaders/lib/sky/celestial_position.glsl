// by BuilderBoy
vec3 GetFixedSunPosition() {
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

    float ang = fract(worldTime / 24000.0 - 0.25);
    ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * (2.0*PI); //0-2pi, rolls over from 2pi to 0 at noon.

    return vec3(-sin(ang), cos(ang) * sunRotationData);
}

vec3 GetSunDir() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE //&& (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return mat3(gbufferModelView) * GetFixedSunPosition();
    #else
        return normalize(sunPosition);
    #endif
}

vec3 GetMoonDir() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE //&& (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return mat3(gbufferModelView) * -GetFixedSunPosition();
    #else
        return normalize(moonPosition);
    #endif
}
