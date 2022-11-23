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

vec3 GetAreaFogColor() {
    return RGBToLinear(fogColor) * 200.0;
}

void GetFog(const in LightData lightData, const in vec3 viewPos, out vec3 fogColorFinal, out float fogFactor) {
    #ifdef SKY_ENABLED
        vec3 viewDir = normalize(viewPos);
        fogColorFinal = GetVanillaSkyLuminance(viewDir);
        //vec2 skyLightLevels = GetSkyLightLevels();
    #else
        fogColorFinal = GetAreaFogColor();
    #endif

    #if MC_VERSION >= 11900
        fogColorFinal *= 1.0 - darknessFactor;
    #endif

    float viewDist = length(viewPos);// - near;
    fogFactor = 0.0;

    float caveLightFactor = saturate(2.0 * lightData.skyLight);
    //#if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        //vec3 caveFogColor = 0.001 * RGBToLinear(vec3(0.3294, 0.1961, 0.6588));
        //vec3 caveFogColorBlend = mix(caveFogColor, atmosphereColor, caveLightFactor);

        //float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
        //float cameraLightFactor = min(6.0 * eyeBrightness, 1.0);
    //#endif

    // #ifdef RENDER_DEFERRED
    //     atmosphereColor *= exposure;
    //     caveFogColor *= exposure;
    // #endif

    #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
        float customFogFactor = GetCustomFogFactor(viewDist, lightData.skyLightLevels.x);
    #endif

    float vanillaFogFactor = GetVanillaFogFactor(viewPos);

    #ifdef SKY_ENABLED
        float rainFogFactor = 0.6 * GetFogFactor(viewDist, 0.0, fogEnd, 0.5) * wetness;
        vanillaFogFactor = min(vanillaFogFactor + rainFogFactor, 1.0);
    #endif

    fogFactor = max(fogFactor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        float caveFogFactor = GetCaveFogFactor(viewDist);

        #ifdef LIGHTLEAK_FIX
            caveFogFactor *= 1.0 - caveLightFactor;
            //caveFogFactor *= 1.0 - cameraLightFactor * vanillaFogFactor;
        #endif

        fogFactor = max(fogFactor, caveFogFactor);
    #endif

    #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
        #ifdef LIGHTLEAK_FIX
            // TODO: reduce cave-fog-factor with distance
            customFogFactor *= caveLightFactor;
        #endif

        fogFactor = max(fogFactor, customFogFactor);
        //color = mix(color, atmosphereColor, customFogFactor);
    #endif

    //color = mix(color, atmosphereColor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        vec3 caveFogColor = 0.001 * RGBToLinear(vec3(0.3294, 0.1961, 0.6588));
        fogColorFinal = mix(fogColorFinal, caveFogColor, caveFogFactor);
    #endif

    // #if defined SKY_ENABLED && !defined VL_SKY_ENABLED
    //     vec3 sunColorFinal = lightData.sunTransmittanceEye * sunColor;
    //     color += maxFactor * GetVanillaSkyScattering(viewDir, lightData.skyLightLevels, sunColorFinal, moonColor);
    // #endif

    //return maxFactor;
}

void ApplyFog(inout vec3 color, const in vec3 fogColor, const in float fogFactor) {
    color = mix(color, fogColor, fogFactor);
}

void ApplyFog(inout vec4 color, const in vec3 fogColor, const in float fogFactor, const in float alphaTestRef) {
    if (color.a > alphaTestRef)
        color.a = mix(color.a, 1.0, fogFactor);

    color.rgb = mix(color.rgb, fogColor, fogFactor);
}

vec2 GetWaterScattering(const in vec3 viewDir) {
    #ifdef SKY_ENABLED
        vec2 scatteringF;

        #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
            vec3 sunDir = GetFixedSunPosition();
        #else
            vec3 sunDir = normalize(sunPosition);
        #endif

        float sun_VoL = dot(viewDir, sunDir);
        scatteringF.x =
            ComputeVolumetricScattering(sun_VoL, 0.6) +
            ComputeVolumetricScattering(sun_VoL, -0.2);

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        scatteringF.y =
            ComputeVolumetricScattering(moon_VoL, 0.6) +
            ComputeVolumetricScattering(moon_VoL, -0.2);

        return 0.3 * max(scatteringF, vec2(0.0));
    #else
        return vec2(0.0);
    #endif
}

vec3 GetWaterFogColor(const in vec3 viewDir, const in vec3 sunColorFinal, const in vec3 moonColorFinal, const in vec2 scatteringF) {
    #ifdef SKY_ENABLED
        vec3 lightColor = scatteringF.x * sunColorFinal + scatteringF.y * moonColorFinal;
        vec3 waterFogColor = vec3(0.0);

        #ifdef SKY_ENABLED
            #ifndef VL_WATER_ENABLED
                waterFogColor += 1.0 * waterScatterColor * lightColor;
            #else
                waterFogColor += 0.08 * waterScatterColor * lightColor;
            #endif
        #endif

        float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
        return waterFogColor * pow2(eyeLight);
    #else
        return vec3(0.0);
    #endif
}

float ApplyWaterFog(inout vec3 color, const in vec3 fogColor, const in float viewDist) {
    //float waterFogEnd = WATER_FOG_DIST;//min(fogEnd, WATER_FOG_DIST);
    float fogFactor = GetFogFactor(viewDist, 0.0, waterFogDistSmooth, 0.25);
    color = mix(color, fogColor, fogFactor);
    return fogFactor;
}
