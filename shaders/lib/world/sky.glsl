const vec3 sunColor = vec3(4.0, 3.0, 2.0);
const vec3 moonColor = vec3(0.05, 0.06, 0.1);


vec3 getSky(const in float UoL) {
    float atmosphere = UoL; //sqrt(1.0-uv.y);
    vec3 skyColor = vec3(0.2, 0.4, 0.8);
    
    float scatter = pow(UoL, 1.0 / 15.0); // iMouse.y / iResolution.y
    scatter = 1.0 - clamp(scatter, 0.8, 1.0);
    
    vec3 scatterColor = mix(vec3(1.0), vec3(1.5, 0.45, 0.0), scatter);
    return mix(skyColor, vec3(scatterColor), atmosphere / 1.3);
}

vec3 getSun(const in float UoL) {
    float sun = UoL; //1.0 - distance(uv,iMouse.xy / iResolution.y);
    //sun = clamp(sun, 0.0, 1.0);
    
    float glow = sun;
    //glow = clamp(glow, 0.0, 1.0);
    
    sun = pow(sun, 100.0);
    sun *= 100.0;
    sun = clamp(sun, 0.0, 1.0);
    
    glow = pow(glow, 6.0) * 1.0;
    glow = pow(glow, UoL); // (uv.y)
    glow = clamp(glow, 0.0, 1.0);
    
    sun *= pow(UoL, 1.0 / 1.65);
    
    glow *= pow(UoL, 1.0 / 2.0);
    
    sun += glow;
    
    return vec3(1.0, 0.6, 0.05) * sun;
}

vec3 GetSkyLightColor() {
    vec3 sunDir = normalize(sunPosition);
    vec3 moonDir = normalize(moonPosition);
    vec3 upDir = normalize(upPosition);
    float sun_UoL = max(dot(upDir, sunDir), 0.0);
    float moon_UoL = max(dot(upDir, moonDir), 0.0);

    vec3 sun_sky = getSky(sun_UoL);
    vec3 sun_light = getSun(sun_UoL);

    //return sun_sky + sun_light * 2.0;

    vec3 moon_sky = getSky(moon_UoL);
    vec3 moon_light = getSun(moon_UoL);
    
    return 2.0 * (sun_sky*sun_UoL + sun_light) + 0.2 * (moon_sky*moon_UoL + moon_light);

    vec3 sunLight = sunColor * sun_UoL;
    vec3 moonLight = moonColor * moon_UoL;
    return sunLight + moonLight;
}
