#if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
    // by BuilderBoy
    vec3 GetFixedSunPosition() {
        const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

        float ang = fract(worldTime / 24000.0 - 0.25);
        ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * (2.0*PI); //0-2pi, rolls over from 2pi to 0 at noon.

        return mat3(gbufferModelView) * vec3(-sin(ang), cos(ang) * sunRotationData);
    }
#endif

// returns: x:sun y:moon
vec2 GetSkyLightLevels() {
    vec3 moonLightDir = normalize(moonPosition);

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        vec3 upDir = gbufferModelView[1].xyz;
        vec3 sunLightDir = GetFixedSunPosition();
    #else
        vec3 upDir = normalize(upPosition);
        vec3 sunLightDir = normalize(sunPosition);
    #endif

    return vec2(
        dot(upDir, sunLightDir),
        dot(upDir, moonLightDir));
}

#ifdef RENDER_FRAG
    #ifdef WORLD_OVERWORLD
        const vec3 skyTint = vec3(0.6, 0.8, 1.0);
    #else
        const vec3 skyTint = vec3(1.0);
    #endif

    float GetVanillaSkyFog(const in float x, const in float w) {
        return w / (x * x + w);
    }

    vec3 GetVanillaSkyLuminance(const in vec3 viewDir) {
        vec2 skyLightLevels = GetSkyLightLevels();

        float lightLevel = saturate(skyLightLevels.x);
        float dayNightF = smoothstep(0.1, 0.6, lightLevel);
        float daySkyLumenFinal = mix(DaySkyLumen, DaySkyOvercastLumen, rainStrength);
        float nightSkyLumenFinal = mix(NightSkyLumen, NightSkyOvercastLumen, rainStrength);
        float skyLumen = mix(nightSkyLumenFinal, daySkyLumenFinal, dayNightF);
        
        // Darken atmosphere
        skyLumen *= 1.0 - saturate((cameraPosition.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));

        vec3 skyColorLinear = RGBToLinear(skyColor);
        if (dot(skyColorLinear, skyColorLinear) < EPSILON) skyColorLinear = vec3(1.0);
        skyColorLinear = normalize(skyColorLinear);

        vec3 fogColorLinear = RGBToLinear(fogColor);
        if (dot(fogColorLinear, fogColorLinear) < EPSILON) fogColorLinear = vec3(1.0);
        fogColorLinear = normalize(fogColorLinear) * 0.8;

        fogColorLinear *= 1.0 - 0.8 * rainStrength;

        #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
            vec3 upDir = gbufferModelView[1].xyz;
        #else
            vec3 upDir = normalize(upPosition);
        #endif

        float VoUm = max(dot(viewDir, upDir), 0.0);
        float skyFogFactor = GetVanillaSkyFog(VoUm, 0.25);
        return mix(skyColorLinear, fogColorLinear, skyFogFactor) * skyLumen;// * skyTint;
    }

    vec3 GetVanillaSkyLux(const in vec3 viewDir) {
        vec2 skyLightLevels = GetSkyLightLevels();
        float lightLevel = saturate(skyLightLevels.x);
        float dayNightF = smoothstep(0.0, 0.6, lightLevel);
        vec3 skyLuxColor = mix(vec3(GetMoonLux()), GetSunLuxColor(), dayNightF);
        
        vec3 skyColorLinear = RGBToLinear(skyColor);
        if (dot(skyColorLinear, skyColorLinear) < EPSILON) skyColorLinear = vec3(1.0);
        skyColorLinear = normalize(skyColorLinear);

        vec3 fogColorLinear = RGBToLinear(fogColor);
        if (dot(fogColorLinear, fogColorLinear) < EPSILON) fogColorLinear = vec3(1.0);
        fogColorLinear = normalize(fogColorLinear) * 0.8;

        #ifdef RENDER_SKYBASIC
            if (isEyeInWater == 1) {
                // TODO: change fogColor to water
                fogColorLinear = vec3(0.0178, 0.0566, 0.0754);
            }
        #endif

        fogColorLinear *= 1.0 - 0.8 * rainStrength;

        #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED)
            vec3 upDir = gbufferModelView[1].xyz;
        #else
            vec3 upDir = normalize(upPosition);
        #endif
        
        float VoUm = max(dot(viewDir, upDir), 0.0);
        float skyFogFactor = GetVanillaSkyFog(VoUm, 0.25);
        return mix(skyColorLinear, fogColorLinear, skyFogFactor) * skyLuxColor;
    }
#endif
