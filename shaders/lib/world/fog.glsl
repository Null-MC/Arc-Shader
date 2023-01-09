float GetFogFactor(const in float dist, const in float start, const in float end, const in float density) {
    float distFactor = dist >= end ? 1.0 : smoothstep(start, end, dist);
    return saturate(pow(distFactor, density));
}

float GetCaveFogFactor(const in float dist) {
    float end = min(60.0, gl_Fog.end);
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

        density = mix(density, rainFogDensity, rainStrength);
        strength = mix(strength, rainFogStrength, rainStrength);

        return saturate(GetFogFactor(viewDist, 0.0, gl_Fog.end, density) * strength);
    }
#endif

float GetVanillaFogFactor(in vec3 viewPos) {
    if (gl_Fog.scale < EPSILON || gl_Fog.end < EPSILON) return 0.0;

    if (fogShape == 1) {
        viewPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        viewPos.y = 0.0;
    }

    float viewDist = length(viewPos);

    float fogFactor;

    if (fogMode == 2)
        fogFactor = exp(-pow((gl_Fog.density * viewDist), 2.0));
    else if (fogMode == 1)
        fogFactor = exp(-gl_Fog.density * viewDist);
    else
        fogFactor = (gl_Fog.end - viewDist) * gl_Fog.scale;

    return 1.0 - saturate(fogFactor);
}

vec3 GetAreaFogColor() {
    return RGBToLinear(fogColor) * FOG_AREA_LUMINANCE;
}

void GetFog(const in LightData lightData, const in vec3 worldPos, const in vec3 viewPos, out vec3 fogColorFinal, out float fogFactor) {
    #ifdef SKY_ENABLED
        vec3 viewDir = normalize(viewPos);

        #if ATMOSPHERE_TYPE == ATMOSPHERE_VANILLA
            fogColorFinal = GetVanillaSkyLuminance(viewDir);
        #else
            //vec3 fogViewDir = mat3(gbufferModelViewInverse) * viewDir;
            //fogViewDir.y = max(fogViewDir.y, 0.0);
            //fogViewDir = mat3(gbufferModelView) * normalize(fogViewDir);

            vec3 sunDir = GetSunDir();

            vec3 atmosPos = worldPos - vec3(cameraPosition.x, SEA_LEVEL, cameraPosition.z);
            atmosPos *= (atmosphereRadiusMM - groundRadiusMM) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
            atmosPos.y = groundRadiusMM + clamp(atmosPos.y, 0.0, atmosphereRadiusMM - groundRadiusMM);

            #if SHADER_PLATFORM == PLATFORM_IRIS
                fogColorFinal = getValFromMultiScattLUT(texMultipleScattering, atmosPos, sunDir) * 256000.0;
            #else
                #ifdef RENDER_DEFERRED
                    fogColorFinal = getValFromMultiScattLUT(colortex1, atmosPos, sunDir) * 256000.0;
                #else
                    fogColorFinal = getValFromMultiScattLUT(colortex14, atmosPos, sunDir) * 256000.0;
                #endif
            #endif
        #endif
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

    float vanillaFogFactor = 0.0;
    #if ATMOSPHERE_TYPE == ATMOSPHERE_VANILLA
        vanillaFogFactor = GetVanillaFogFactor(viewPos);
    #elif !defined VL_SKY_ENABLED
        float p = mix(1.4, 0.8, wetness);
        vanillaFogFactor = GetFogFactor(viewDist, 0.0, far, p) * 0.4;
    #endif

    #ifdef SKY_ENABLED
        float rainFogFactor = 0.6 * GetFogFactor(viewDist, 0.0, gl_Fog.end, 0.5) * wetness;
        vanillaFogFactor = min(vanillaFogFactor + rainFogFactor, 1.0);
    #endif

    fogFactor = max(fogFactor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        float caveFogFactor = GetCaveFogFactor(viewDist);

        #ifdef LIGHTLEAK_FIX
            caveFogFactor *= 1.0 - caveLightFactor;
            //caveFogFactor *= 1.0 - cameraLightFactor * vanillaFogFactor;
        #endif

        //fogFactor = max(fogFactor, caveFogFactor);
    #endif

    #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
        #ifdef LIGHTLEAK_FIX
            // TODO: reduce cave-fog-factor with distance
            customFogFactor *= caveLightFactor;
        #endif

        //fogFactor = max(fogFactor, customFogFactor);
        //color = mix(color, atmosphereColor, customFogFactor);
    #endif

    //color = mix(color, atmosphereColor, vanillaFogFactor);

    #if defined CAVEFOG_ENABLED && defined SHADOW_ENABLED
        vec3 caveFogColor = 0.001 * RGBToLinear(vec3(0.3294, 0.1961, 0.6588));
        fogColorFinal = mix(fogColorFinal, caveFogColor, caveFogFactor);
    #endif
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
            vec3 sunDir = mat3(gbufferModelView) * GetFixedSunPosition();
        #else
            vec3 sunDir = normalize(sunPosition);
        #endif

        float sun_VoL = dot(viewDir, sunDir);
        scatteringF.x = mix(
            ComputeVolumetricScattering(sun_VoL, -0.2),
            ComputeVolumetricScattering(sun_VoL, 0.6),
            0.7);

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        scatteringF.y = mix(
            ComputeVolumetricScattering(moon_VoL, -0.2),
            ComputeVolumetricScattering(moon_VoL, 0.6),
            0.7);

        return max(scatteringF, vec2(0.0));
    #else
        return vec2(0.0);
    #endif
}

vec3 GetWaterFogColor(const in vec3 sunColorFinal, const in vec3 moonColorFinal, const in vec2 scatteringF) {
    #ifdef SKY_ENABLED
        vec3 waterFogColor = vec3(0.0);

        #ifdef SKY_ENABLED
            #ifdef VL_WATER_ENABLED
                vec3 lightColor = sunColorFinal + moonColorFinal;
                waterFogColor += 0.004 * waterScatterColor * lightColor;
            #else
                vec3 lightColor = scatteringF.x * sunColorFinal + scatteringF.y * moonColorFinal;
                waterFogColor += 0.6 * waterScatterColor * lightColor;
            #endif
        #endif

        float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
        return waterFogColor * pow2(eyeLight);
    #else
        return vec3(0.0);
    #endif
}

float ApplyWaterFog(inout vec3 color, const in vec3 fogColor, const in float viewDist) {
    float fogFactor = GetFogFactor(viewDist, 0.0, waterFogDistSmooth, 0.25);
    color = mix(color, fogColor, fogFactor);
    return fogFactor;
}
