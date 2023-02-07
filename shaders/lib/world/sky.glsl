// returns: x:sun y:moon
vec2 GetSkyLightLevels() {
    #ifndef IS_IRIS
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
