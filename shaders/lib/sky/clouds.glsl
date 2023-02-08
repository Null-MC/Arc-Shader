float GetCloudDensity(const in vec2 pos, const in float time) {
    vec3 uv = vec3(pos, time);

    float f = 0.0;
    float weight = 0.7;
    float maxWeight = 0.0;
    for (int i = 0; i < 6; i++) {
        vec2 noise = texture(TEX_CLOUD_NOISE, uv).rg;

        f += weight * noise.r;
        uv.xy *= 2.0;
        maxWeight += weight;
        weight *= 0.6;
    }

    f /= maxWeight;

    f = smoothstep(0.42, 1.0, f);

    f = pow(f, 0.6);
    //f = pow(f, 1.1 - 0.2*rainStrength);

    return f;
}

bool HasClouds(const in vec3 worldPos, const in vec3 localViewDir) {
    return step(worldPos.y, CLOUD_LEVEL) == step(0.0, localViewDir.y);
}

vec3 GetCloudPosition(const in vec3 worldPos, const in vec3 localViewDir) {
    return worldPos + (localViewDir / localViewDir.y) * (CLOUD_LEVEL - worldPos.y);
}

float GetCloudFactor(const in vec3 cloudPos, const in vec3 localViewDir, const in float lod) {
    float time = frameTimeCounter / 36.0;
    float d = GetCloudDensity(cloudPos.xz * 0.0008, time);
    
    d = saturate(d);
    d = pow(d, 1.0 - 0.6 * wetness);

    float viewDirY = localViewDir.y;

    if (cameraPosition.y > CLOUD_LEVEL)
        viewDirY = -viewDirY;

    return d * smoothstep(0.06, 0.8, viewDirY);
}

vec3 GetCloudColor(const in vec3 cloudPos, const in vec3 localViewDir, const in vec2 skyLightLevels) {
    vec3 atmosPos = GetAtmospherePosition(cloudPos);

    vec3 localSunDir = GetSunLocalDir();
    float sun_VoL = dot(localViewDir, localSunDir);

    float sunScatterF = mix(
        ComputeVolumetricScattering(sun_VoL, -0.24),
        ComputeVolumetricScattering(sun_VoL, 0.86),
        0.3);

    #ifdef IS_IRIS
        vec3 sunTransmittance = getValFromTLUT(texSunTransmittance, atmosPos, localSunDir);
    #else
        vec3 sunTransmittance = getValFromTLUT(colortex12, atmosPos, localSunDir);
    #endif

    #ifdef WORLD_MOON_ENABLED
        vec3 localMoonDir = GetMoonLocalDir();
        float moon_VoL = dot(localViewDir, localMoonDir);

        float moonScatterF = mix(
            ComputeVolumetricScattering(moon_VoL, -0.24),
            ComputeVolumetricScattering(moon_VoL, 0.86),
            0.3);

        #ifdef IS_IRIS
            vec3 moonTransmittance = getValFromTLUT(texSunTransmittance, atmosPos, localMoonDir);
        #else
            vec3 moonTransmittance = getValFromTLUT(colortex12, atmosPos, localMoonDir);
        #endif
    #endif

    vec3 sunColorFinal = sunTransmittance * skySunColor * SunLux;// * smoothstep(-0.06, 0.6, skyLightLevels.x);
    vec3 vl = sunColorFinal * sunScatterF;
    vec3 ambient = sunColorFinal;

    #ifdef WORLD_MOON_ENABLED
        vec3 moonColorFinal = moonTransmittance * skyMoonColor * MoonLux * GetMoonPhaseLevel();// * smoothstep(-0.06, 0.6, skyLightLevels.y);
        vl += moonColorFinal * moonScatterF;
        ambient += moonColorFinal;
    #endif

    return (ambient * 0.2 + vl) * CLOUD_COLOR * pow(1.0 - 0.9 * rainStrength, 2.0);
}
