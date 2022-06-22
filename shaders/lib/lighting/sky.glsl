vec3 GetSkyLightColor() {
    vec3 sunDir = normalize(sunPosition);
    vec3 moonDir = normalize(moonPosition);
    vec3 upDir = normalize(upPosition);
    float sun_UoL = dot(upDir, sunDir);
    float moon_UoL = dot(upDir, moonDir);

    vec3 sunColor = vec3(2.0) * max(sun_UoL, 0.0);
    vec3 moonColor = vec3(0.1) * max(moon_UoL, 0.0);
    return sunColor + moonColor;
}
