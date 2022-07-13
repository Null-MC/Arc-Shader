const float[5] moonPhaseLevels = float[](0.08, 0.25, 0.50, 0.75, 1.0);

float GetSolidAngle(const in float angularDiameter) {
    return 2.0 * PI * (1.0 - cos(0.5 * angularDiameter * PI * 180.0));
}

// returns: x:sun y:moon
vec2 GetSkyLightLevels() {
    vec3 upDir = normalize(upPosition);
    vec3 sunLightDir = normalize(sunPosition);
    vec3 moonLightDir = normalize(moonPosition);

    return vec2(
        dot(upDir, sunLightDir),
        dot(upDir, moonLightDir));
}

float GetSunLightLevel(const in float skyLightLevel) {
    float rainLevel = 1.0 - 0.98 * rainStrength;

    //float angularDiameter = mix(0.526, 0.545, max(skyLightLevel, 0.0));
    //return GetSolidAngle(angularDiameter);

    // TODO: This angle is wrong and sucks
    return pow(max(0.1 + 0.9*skyLightLevel, 0.0), 0.8) * rainLevel;
}

float GetMoonLightLevel(const in float skyLightLevel) {
    float rainLevel = 1.0 - 0.9 * rainStrength;
    float moonPhaseLevel = moonPhaseLevels[abs(moonPhase-4)];

    //float angularDiameter = mix(0.49, 0.55, max(skyLightLevel, 0.0));
    //return GetSolidAngle(angularDiameter) * moonPhaseLevel;

    // TODO: This angle is wrong and sucks
    return pow(max(0.1 + 0.9*skyLightLevel, 0.0), 0.8) * rainLevel * moonPhaseLevel;
}

#ifndef RENDER_SKYBASIC
    // returns: x:sun y:moon temp in kelvin
    vec2 GetSkyLightTemp(const in vec2 skyLightLevels) {
        const float temp_sunrise = 1850; // 2000
        const float temp_day = 5500; // 5000
        const float temp_rain = 6500; // 8000
        const float temp_moon = 4150; // 5500

        float sunTemp = mix(temp_sunrise, temp_day, max(skyLightLevels.x, 0.0));
        sunTemp = mix(sunTemp, temp_rain, rainStrength);

        return vec2(sunTemp, temp_moon);
    }

    vec3 GetSunLightColor(const in float temp, const in float skyLightLevel) {
        return blackbody(temp) * GetSunLightLevel(skyLightLevel);
    }

    vec3 GetMoonLightColor(const in float temp, const in float skyLightLevel) {
        return blackbody(temp) * GetMoonLightLevel(skyLightLevel);
    }

    vec3 GetSunLightLux(const in float temp, const in float skyLightLevel) {
        float lux = mix(SunLux, SunOvercastLux, rainStrength);
        return GetSunLightColor(temp, skyLightLevel) * lux;
    }

    vec3 GetMoonLightLux(const in float temp, const in float skyLightLevel) {
        float lux = mix(MoonLux, MoonOvercastLux, rainStrength);
        return GetSunLightColor(temp, skyLightLevel) * lux;
    }

    vec3 GetSkyLightLuminance(const in vec2 skyLightLevels) {
        //vec2 skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);

        vec3 sunLum = GetSunLightLux(skyLightTemp.x, skyLightLevels.x); //GetSunLightColor(skyLightTemp.x, skyLightLevels.x) * SunLux;
        vec3 moonLum = GetMoonLightLux(skyLightTemp.y, skyLightLevels.y); //GetMoonLightColor(skyLightTemp.y, skyLightLevels.y) * MoonLux;

        return sunLum + moonLum;
    }

    // returns: x:sun y:moon
    // vec2 GetSkyLightIntensity() {
    //     vec2 skyLightLevels = GetSkyLightLevels();
    //     float sunLightStrength = pow(skyLightLevels.x, 0.3);
    //     float moonLightStrength = pow(skyLightLevels.y, 0.3);

    //     vec2 skyLightIntensity = vec2(
    //         sunLightStrength * sunIntensity,
    //         moonLightStrength * moonIntensity);

    //     skyLightIntensity *= 1.0 - rainStrength * (1.0 - RAIN_DARKNESS);

    //     return skyLightIntensity;
    // }

    // vec3 GetSkyLightColor(const in vec2 skyLightIntensity) {
    //     return sunColor * skyLightIntensity.x + moonColor * skyLightIntensity.y;
    // }

    // vec3 GetSkyLightColor() {
    //     return GetSkyLightColor(GetSkyLightIntensity());
    // }
#endif

#ifdef RENDER_FRAG
    float GetVanillaSkyFog(float x, float w) {
        return w / (x * x + w);
    }

    vec3 GetVanillaSkyLuminance(const in vec3 viewDir) {
        vec2 skyLightLevels = GetSkyLightLevels();
        float sunSkyLumen = GetSunLightLevel(skyLightLevels.x) * DaySkyLumen;
        float moonSkyLumen = GetMoonLightLevel(skyLightLevels.y) * NightSkyLumen;
        float skyLumen = sunSkyLumen + moonSkyLumen;

        vec3 skyColorLinear = RGBToLinear(skyColor) * skyLumen;
        vec3 fogColorLinear = RGBToLinear(fogColor) * skyLumen;

        vec3 upDir = normalize(upPosition);
        float VoUm = max(dot(viewDir, upDir), 0.0);
        float skyFogFactor = GetVanillaSkyFog(VoUm, 0.25);
        return mix(skyColorLinear, fogColorLinear, skyFogFactor);
    }

    vec3 GetVanillaSkyLux(const in vec3 viewDir) {
        vec2 skyLightLevels = GetSkyLightLevels();
        float sunLightLux = GetSunLightLevel(skyLightLevels.x) * SunLux;
        float moonLightLux = GetMoonLightLevel(skyLightLevels.y) * MoonLux;
        float skyLux = sunLightLux + moonLightLux;

        vec3 skyColorLinear = RGBToLinear(skyColor) * skyLux;
        vec3 fogColorLinear = RGBToLinear(fogColor) * skyLux;

        vec3 upDir = normalize(upPosition);
        float VoUm = max(dot(viewDir, upDir), 0.0);
        float skyFogFactor = GetVanillaSkyFog(VoUm, 0.25);
        return mix(skyColorLinear, fogColorLinear, skyFogFactor);
    }
#endif
