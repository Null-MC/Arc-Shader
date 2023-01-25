// returns: x:sun y:moon
vec2 GetSkyLightLevels() {
    #if SHADER_PLATFORM == PLATFORM_OPTIFINE //&& (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        vec3 sunLightDir = GetSunLocalDir();
        vec3 moonLightDir = -sunLightDir;
        vec3 upDir = vec3(0.0, 1.0, 0.0);
    #else
        vec3 sunLightDir = GetSunViewDir();
        vec3 moonLightDir = GetMoonViewDir();
        vec3 upDir = normalize(upPosition);
    #endif

    return vec2(
        dot(upDir, sunLightDir),
        dot(upDir, moonLightDir));
}
