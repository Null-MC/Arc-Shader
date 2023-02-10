float GetFogFactor(const in float dist, const in float start, const in float end, const in float density) {
    float distFactor = dist >= end ? 1.0 : smoothstep(start, end, dist);
    return saturate(pow(distFactor, density));
}

#ifndef SKY_ENABLED
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

    void GetVanillaFog(const in LightData lightData, const in vec3 viewPos, out vec3 fogColorFinal, out float fogFactor) {
        fogColorFinal = GetAreaFogColor();

        #if MC_VERSION >= 11900
            fogColorFinal *= 1.0 - darknessFactor;
        #endif

        float viewDist = length(viewPos);// - near;
        fogFactor = 0.0;

        #if defined SKY_ENABLED && defined ATMOSFOG_ENABLED
            float customFogFactor = GetCustomFogFactor(viewDist, lightData.skyLightLevels.x);
        #endif

        float vanillaFogFactor = GetVanillaFogFactor(viewPos);

        fogFactor = max(fogFactor, vanillaFogFactor);
    }

    void ApplyFog(inout vec3 color, const in vec3 fogColor, const in float fogFactor) {
        color = mix(color, fogColor, fogFactor);
    }

    void ApplyFog(inout vec4 color, const in vec3 fogColor, const in float fogFactor, const in float alphaTestRef) {
        if (color.a > alphaTestRef)
            color.a = mix(color.a, 1.0, fogFactor);

        color.rgb = mix(color.rgb, fogColor, fogFactor);
    }
#endif

#ifdef WORLD_WATER_ENABLED
    vec3 GetWaterFogColor(const in vec3 sunColorFinal, const in vec3 moonColorFinal, const in vec2 scatteringF) {
        #ifdef SKY_ENABLED
            vec3 waterFogColor = vec3(0.0);

            #if defined VL_WATER_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                const float isotropicPhase = 0.25 / PI;
                vec3 lightColor = isotropicPhase * (sunColorFinal + moonColorFinal);
            #else
                vec3 lightColor = scatteringF.x * sunColorFinal + scatteringF.y * moonColorFinal;
            #endif

            vec3 ext = 1.0 - RGBToLinear(waterAbsorbColor);
            float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
            float lightDist = mix(4.0, 22.0, 1.0 - eyeLight);
            waterFogColor = lightColor * exp(-ext * lightDist);

            return waterFogColor;
        #else
            return vec3(0.0);
        #endif
    }

    float GetWaterFogFactor(const in float waterNear, const in float viewDist) {
        return GetFogFactor(viewDist, waterNear, waterNear + waterFogDistSmooth, 1.0);
    }

    float ApplyWaterFog(inout vec3 color, const in vec3 fogColor, const in float viewDist) {
        float fogFactor = GetWaterFogFactor(0.0, viewDist);
        color = mix(color, fogColor, fogFactor);
        return fogFactor;
    }
#endif
