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
        return fogColor * FOG_AREA_LUMINANCE;
    }

    void GetVanillaFog(const in LightData lightData, const in vec3 viewPos, out vec3 fogColorFinal, out float fogFactor) {
        fogColorFinal = GetAreaFogColor();

        #if MC_VERSION >= 11900
            fogColorFinal *= 1.0 - darknessFactor;
        #endif

        //fogFactor = GetVanillaFogFactor(viewPos);

        float viewDist = length(viewPos) - near;
        fogFactor = GetFogFactor(viewDist, 0.0, far, 1.0);
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
            vec3 lightColor = scatteringF.x * sunColorFinal + scatteringF.y * moonColorFinal;

            vec3 ext = 1.0 - waterAbsorbColor;
            float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
            float lightDist = mix(20.0, 4.0, eyeLight);
            vec3 waterFogColor = lightColor * exp(-ext * lightDist);

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
