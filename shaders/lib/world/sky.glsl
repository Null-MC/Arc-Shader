// returns: x:sun y:moon
vec2 GetSkyLightLevels() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        vec3 upDir = vec3(0.0, 1.0, 0.0);
        vec3 sunLightDir = GetFixedSunPosition();
        vec3 moonLightDir = -sunLightDir;
    #else
        vec3 upDir = normalize(upPosition);
        vec3 sunLightDir = normalize(sunPosition);
        vec3 moonLightDir = normalize(moonPosition);
    #endif

    return vec2(
        dot(upDir, sunLightDir),
        dot(upDir, moonLightDir));
}
