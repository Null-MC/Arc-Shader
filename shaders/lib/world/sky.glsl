#ifndef RENDER_SKYBASIC
    // returns: x:sun y:moon
    vec2 GetSkyLightLevels() {
        vec3 upDir = normalize(upPosition);
        vec3 sunLightDir = normalize(sunPosition);
        vec3 moonLightDir = normalize(moonPosition);

        return vec2(
            dot(upDir, sunLightDir),
            dot(upDir, moonLightDir));
    }

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

    vec3 GetSunLightLuminance(const in float temp, const in float level) {
        // TODO: This angle is wrong and sucks
        float angleIntensity = pow(max(0.1 + 0.9*level, 0.0), 0.5);
        return blackbody(temp) * SunIntensityWM2 * angleIntensity;
    }

    vec3 GetMoonLightLuminance(const in float temp, const in float level) {
        // TODO: This angle is wrong and sucks
        float angleIntensity = pow(max(0.1 + 0.9*level, 0.0), 0.5);
        return blackbody(temp) * MoonIntensityWM2 * angleIntensity;
    }

    vec3 GetSkyLightLuminance(const in vec2 skyLightLevels) {
        //vec2 skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);

        vec3 sunLum = GetSunLightLuminance(skyLightTemp.x, skyLightLevels.x);
        vec3 moonLum = GetMoonLightLuminance(skyLightTemp.y, skyLightLevels.y);

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

    vec3 GetVanillaSkyColor(const in vec3 viewDir) {
        vec3 skyColorLinear = RGBToLinear(skyColor);
        vec3 fogColorLinear = RGBToLinear(fogColor);

        skyColorLinear *= 280.0;
        fogColorLinear *= 200.0;

        vec3 upDir = normalize(upPosition);
        float VoUm = max(dot(viewDir, upDir), 0.0);
        float skyFogFactor = GetVanillaSkyFog(VoUm, 0.25);
        return mix(skyColorLinear, fogColorLinear, skyFogFactor);
    }
#endif
