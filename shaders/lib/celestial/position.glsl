// by BuilderBoy
vec3 GetFixedSunPosition() {
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

    float ang = fract(worldTime / 24000.0 - 0.25);
    ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * (2.0*PI); //0-2pi, rolls over from 2pi to 0 at noon.

    return vec3(-sin(ang), cos(ang) * sunRotationData);
}

vec3 GetEndSunPosition() {
    float time = fract(worldTime / 24000.0);

    float pan = time * 12.0 * TAU;
    float tilt = (0.1 + 0.4 * sin(time * PI)) * (0.5*PI);
    return vec3(sin(pan) * cos(tilt), sin(tilt), cos(pan) * cos(tilt));
}

vec3 GetSunLocalDir() {
    #ifdef WORLD_END
        return normalize(GetEndSunPosition());
    #elif SHADER_PLATFORM == PLATFORM_OPTIFINE //&& (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return normalize(GetFixedSunPosition());
    #else
        return normalize(mat3(gbufferModelViewInverse) * sunPosition);
    #endif
}

vec3 GetSunViewDir() {
    #ifdef WORLD_END
        return normalize(mat3(gbufferModelView) * GetEndSunPosition());
    #elif SHADER_PLATFORM == PLATFORM_OPTIFINE //&& (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return normalize(mat3(gbufferModelView) * GetFixedSunPosition());
    #else
        return normalize(sunPosition);
    #endif
}

vec3 GetMoonLocalDir() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE //&& (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return -GetFixedSunPosition();
    #else
        return normalize(mat3(gbufferModelViewInverse) * moonPosition);
    #endif
}

vec3 GetMoonViewDir() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE //&& (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        return mat3(gbufferModelView) * -GetFixedSunPosition();
    #else
        return normalize(moonPosition);
    #endif
}

vec3 GetShadowLightLocalPosition() {
    #ifdef WORLD_END
        return GetEndSunPosition();
    #else
        #if SHADER_PLATFORM == PLATFORM_OPTIFINE
            return GetFixedSunPosition();
        #else
            return (gbufferModelViewInverse * vec4(shadowLightPosition, 1.0)).xyz;
        #endif
    #endif
}

vec3 GetShadowLightLocalDir() {
    return normalize(GetShadowLightLocalPosition());
}

vec3 GetShadowLightViewPosition() {
    #ifdef WORLD_END
        return mat3(gbufferModelView) * GetEndSunPosition();
    #else
        #if SHADER_PLATFORM == PLATFORM_OPTIFINE
            return mat3(gbufferModelView) * GetFixedSunPosition();
        #else
            return shadowLightPosition;
        #endif
    #endif
}

vec3 GetShadowLightViewDir() {
    return normalize(GetShadowLightViewPosition());
}
