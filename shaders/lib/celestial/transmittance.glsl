vec3 GetTransmittance(const in sampler3D tex, const in float elevation, const in float skyLightLevel) {
    vec3 uv = getAtmosLUT_UV(skyLightLevel, elevation);
    return textureLod(tex, uv, 0).rgb;
}

vec3 GetWorldTransmittance(const in sampler3D tex, const in float worldY, const in float skyLightLevel) {
    float elevation = GetScaledSkyHeight(worldY);
    return GetTransmittance(tex, elevation, skyLightLevel);
}

float GetSunLux() {
    #ifdef WORLD_END
        return SunLux;
    #else
        return mix(SunLux, SunOvercastLux, rainStrength);
    #endif
}

vec3 GetSunColor() {
    #ifdef WORLD_END
        return vec3(0.0, 1.0, 0.0);
    #else
        return blackbody(SUN_TEMP);
    #endif
}

vec3 GetSunLuxColor() {
    return GetSunLux() * GetSunColor();
}

#ifdef WORLD_MOON_ENABLED
    const float[5] moonPhaseLevels = float[](0.1, 0.4, 0.7, 0.9, 1.0);

    float GetMoonLux() {
        #ifdef WORLD_END
            return MoonLux;
        #else
            return mix(MoonLux, MoonOvercastLux, rainStrength);
        #endif
    }

    vec3 GetMoonColor() {
        return blackbody(MOON_TEMP);
    }

    vec3 GetMoonLuxColor() {
        return GetMoonLux() * GetMoonColor();
    }

    float GetMoonPhaseLevel() {
        return moonPhaseLevels[abs(moonPhase - 4)];
    }
#endif
