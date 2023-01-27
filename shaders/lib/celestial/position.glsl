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

vec3 GetSunLocalPosition() {
    #ifdef WORLD_END
        return GetEndSunPosition();
    #else
        return GetFixedSunPosition();
    #endif
}

vec3 GetSunLocalDir() {
    return normalize(GetSunLocalPosition());
}

vec3 GetSunViewDir() {
    return mat3(gbufferModelView) * GetSunLocalDir();
}

vec3 GetMoonLocalPosition() {
    return -GetSunLocalPosition();
}

vec3 GetMoonLocalDir() {
    return -GetSunLocalDir();
}

vec3 GetMoonViewDir() {
    return -GetSunViewDir();
}

//#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    vec3 GetShadowLightLocalPosition() {
        #ifdef WORLD_END
            return GetEndSunPosition();
        #else
            vec3 sunDir = GetFixedSunPosition();

            if (worldTime >= 13000 && worldTime <= 23000)
                sunDir = -sunDir;

            return sunDir;
        #endif
    }

    vec3 GetShadowLightLocalDir() {
        return normalize(GetShadowLightLocalPosition());
    }

    vec3 GetShadowLightViewPosition() {
        return mat3(gbufferModelView) * GetShadowLightLocalPosition();
    }

    vec3 GetShadowLightViewDir() {
        return normalize(GetShadowLightViewPosition());
    }
//#endif
