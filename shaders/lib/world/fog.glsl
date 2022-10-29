float GetFogFactor(const in float dist, const in float start, const in float end, const in float density) {
    //float distFactor = min(max(dist - start, 0.0) / (end - start), 1.0);
    float distFactor = dist >= end ? 1.0 : smoothstep(start, end, dist);
    return saturate(pow(distFactor, density));
}

float GetCaveFogFactor(const in float dist) {
    float end = min(60.0, fogEnd);
    return GetFogFactor(dist, 0.0, end, 1.0);
}

#ifdef SKY_ENABLED
    float GetCustomFogFactor(const in float viewDist, const in float sunLightLevel) {
        const float dayFogDensity = 1.5;
        const float nightFogDensity = 1.2;
        const float rainFogDensity = 1.0;

        const float dayFogStrength = 0.2;
        const float nightFogStrength = 0.3;
        const float rainFogStrength = 0.8;

        float density = mix(nightFogDensity, dayFogDensity, saturate(sunLightLevel));
        float strength = mix(nightFogStrength, dayFogStrength, saturate(sunLightLevel));

        // #ifdef IS_OPTIFINE
        //     //density = mix(density, rainFogDensity, rainStrength);
        //     density = max(density - 0.2 * eyeHumidity, 0.0);
        //     strength = min(strength + 0.4 * eyeHumidity, 1.0);
        // #endif

        density = mix(density, rainFogDensity, rainStrength);
        strength = mix(strength, rainFogStrength, rainStrength);

        return saturate(GetFogFactor(viewDist, 0.0, fogEnd, density) * strength);
    }
#endif

float GetVanillaFogFactor(const in vec3 viewPos) {
    vec3 fogPos = viewPos;
    if (fogShape == 1) {
        fogPos = (gbufferModelViewInverse * vec4(fogPos, 1.0)).xyz;
        fogPos.y = 0.0;
    }

    float fogDist = length(fogPos);
    return GetFogFactor(fogDist, fogStart, fogEnd, 1.0);
}

float ApplyFog(inout vec3 color, const in vec3 viewPos, const in LightData lightData) {
    #ifdef SKY_ENABLED
        vec3 viewDir = normalize(viewPos);
        vec3 atmosphereColor = GetVanillaSkyLuminance(viewDir);
        //vec2 skyLightLevels = GetSkyLightLevels();
    #else
        vec3 atmosphereColor = RGBToLinear(fogColor) * 100.0;
    #endif

    #if MC_VERSION >= 11900
        atmosphereColor *= 1.0 - darknessFactor;
    #endif

    float viewDist = length(viewPos);// - near;
    float maxFactor = 0.0;

    float caveLightFactor = saturate(2.0 * lightData.skyLight);
    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        vec3 caveFogColor = 0.001 * RGBToLinear(vec3(0.3294, 0.1961, 0.6588));
        vec3 caveFogColorBlend = mix(caveFogColor, atmosphereColor, caveLightFactor);

        float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
        float cameraLightFactor = min(6.0 * eyeBrightness, 1.0);
    #endif

    // #ifdef RENDER_DEFERRED
    //     atmosphereColor *= exposure;
    //     caveFogColor *= exposure;
    // #endif

    #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
        float sunLightLevel = GetSunLightLevel(lightData.skyLightLevels.x);

        float customFogFactor = GetCustomFogFactor(viewDist, sunLightLevel);
    #endif

    float vanillaFogFactor = GetVanillaFogFactor(viewPos);

    #ifdef SKY_ENABLED
        float rainFogFactor = 0.6 * GetFogFactor(viewDist, 0.0, fogEnd, 0.5) * wetness;
        vanillaFogFactor = min(vanillaFogFactor + rainFogFactor, 1.0);
    #endif

    maxFactor = max(maxFactor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        float caveFogFactor = GetCaveFogFactor(viewDist);

        #ifdef LIGHTLEAK_FIX
            caveFogFactor *= 1.0 - caveLightFactor;
            //caveFogFactor *= 1.0 - cameraLightFactor * vanillaFogFactor;
        #endif

        maxFactor = max(maxFactor, caveFogFactor);
    #endif

    #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
        #ifdef LIGHTLEAK_FIX
            // TODO: reduce cave-fog-factor with distance
            customFogFactor *= caveLightFactor;
        #endif

        maxFactor = max(maxFactor, customFogFactor);
        color = mix(color, atmosphereColor, customFogFactor);
    #endif

    color = mix(color, atmosphereColor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        color = mix(color, caveFogColorBlend, caveFogFactor);
    #endif

    // #if defined SKY_ENABLED && !defined VL_ENABLED
    //     vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux();// * sunColor
    //     color += maxFactor * GetVanillaSkyScattering(viewDir, lightData.skyLightLevels, sunColorFinal, moonColor);
    // #endif

    return maxFactor;
}

float ApplyFog(inout vec4 color, const in vec3 viewPos, const in LightData lightData, const in float alphaTestRef) {
    float fogFactor = ApplyFog(color.rgb, viewPos, lightData);

    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogFactor);

    return fogFactor;
}

vec3 GetWaterFogColor(const in vec3 viewDir, const in vec3 sunTransmittance, const in vec3 sunTransmittanceEye) {
    vec3 waterFogColor = 0.025*WATER_COLOR.rgb * sunTransmittance * GetSunLux();

    float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
    //vec3 waterFogColor = skyLightColor;

    #ifdef SKY_ENABLED
        // TODO: add sun VL
        const float scatter_G = 0.5;

        #if defined IS_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
            vec3 sunDir = GetFixedSunPosition();
        #else
            vec3 sunDir = normalize(sunPosition);
        #endif

        float sun_VoL = dot(viewDir, sunDir);
        float sunScattering = ComputeVolumetricScattering(sun_VoL, scatter_G);
        // vec3 sunTransmittance = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);
        waterFogColor += 0.4*saturate(sunScattering) * sunTransmittanceEye * GetSunLux() * WATER_SCATTER_COLOR;

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        float moonScattering = ComputeVolumetricScattering(moon_VoL, scatter_G);
        waterFogColor += 0.4*saturate(moonScattering) * moonColor * WATER_SCATTER_COLOR;
    #endif

    return waterFogColor * pow3(eyeLight);
}

float ApplyWaterFog(inout vec3 color, const in LightData lightData, const in float lightDist, const in vec3 viewDir) {
    float waterFogEnd = WATER_FOG_DIST;//min(fogEnd, WATER_FOG_DIST);
    float fogFactor = GetFogFactor(lightDist, 0.0, waterFogEnd, 0.5);
    vec3 waterFogColor = GetWaterFogColor(viewDir, lightData.sunTransmittance, lightData.sunTransmittanceEye);
    //waterFogColor *= pow3(lightData.skyLight);
    color = mix(color, waterFogColor, fogFactor);
    return fogFactor;
}
