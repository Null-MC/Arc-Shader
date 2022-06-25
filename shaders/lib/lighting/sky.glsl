vec3 GetSkyLightColor() {
    vec3 sunDir = normalize(sunPosition);
    vec3 moonDir = normalize(moonPosition);
    vec3 upDir = normalize(upPosition);
    float sun_UoL = dot(upDir, sunDir);
    float moon_UoL = dot(upDir, moonDir);

    vec3 sunColor = vec3(4.0) * max(sun_UoL, 0.0);
    vec3 moonColor = vec3(0.06) * max(moon_UoL, 0.0);
    return sunColor + moonColor;
}
