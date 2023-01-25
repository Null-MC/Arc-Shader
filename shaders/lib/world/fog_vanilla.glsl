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

            #ifdef SKY_ENABLED
                #ifdef VL_WATER_ENABLED
                    vec3 lightColor = sunColorFinal + moonColorFinal;
                    waterFogColor += 0.004 * waterScatterColor * lightColor;
                #else
                    vec3 lightColor = scatteringF.x * sunColorFinal + scatteringF.y * moonColorFinal;
                    waterFogColor += 0.4 * waterScatterColor * lightColor;
                #endif
            #endif

            float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
            return waterFogColor * pow2(eyeLight);
        #else
            return vec3(0.0);
        #endif
    }

    float GetWaterFogFactor(const in float waterNear, const in float viewDist) {
        return GetFogFactor(viewDist, waterNear, waterNear + waterFogDistSmooth, 0.25);
    }

    float ApplyWaterFog(inout vec3 color, const in vec3 fogColor, const in float viewDist) {
        float fogFactor = GetWaterFogFactor(0.0, viewDist);
        color = mix(color, fogColor, fogFactor);
        return fogFactor;
    }
#endif
