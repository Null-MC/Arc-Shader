// These are per megameter.
const float groundRadiusMM = 3.360;
const float atmosphereRadiusMM = 3.460;

const vec3 ozoneAbsorptionBase_clear = vec3(0.650, 1.381, 0.576);
const vec3 rayleighScatteringBase_clear = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase_clear = 8.0;
const float mieScatteringBase_clear = 3.996 * 12.0;
const float mieAbsorptionBase_clear = 4.4 * 4.0;

const vec3 ozoneAbsorptionBase_rain = vec3(0.650, 1.381, 0.576);
const vec3 rayleighScatteringBase_rain = vec3(80.802, 130.558, 200.1);
const float rayleighAbsorptionBase_rain = 8.0;
const float mieScatteringBase_rain = 3.996 * 96.0;
const float mieAbsorptionBase_rain = 4.4 * 6.0;

const vec3 ozoneAbsorptionBase_end = vec3(0.650, 8.381, 8.576);
const vec3 rayleighScatteringBase_end = vec3(64.802, 6.558, 28.1);
const float rayleighAbsorptionBase_end = 6.0;
const float mieScatteringBase_end = 3.996 * 4.0;
const float mieAbsorptionBase_end = 4.4 * 10.0;


vec3 GetOzoneAbsorptionBase() {
    #ifdef WORLD_END
        return ozoneAbsorptionBase_end;
    #else
        return mix(ozoneAbsorptionBase_clear, ozoneAbsorptionBase_rain, rainStrength);
    #endif
}

vec3 GetRayleighScatteringBase() {
    #ifdef WORLD_END
        return rayleighScatteringBase_end;
    #else
        return mix(rayleighScatteringBase_clear, rayleighScatteringBase_rain, rainStrength);
    #endif
}

float GetRayleighAbsorptionBase() {
    #ifdef WORLD_END
        return rayleighAbsorptionBase_end;
    #else
        return mix(rayleighAbsorptionBase_clear, rayleighAbsorptionBase_rain, rainStrength);
    #endif
}

float GetMieScatteringBase() {
    #ifdef WORLD_END
        return mieScatteringBase_end;
    #else
        return mix(mieScatteringBase_clear, mieScatteringBase_rain, rainStrength);
    #endif
}

float GetMieAbsorptionBase() {
    #ifdef WORLD_END
        return mieAbsorptionBase_end;
    #else
        return mix(mieAbsorptionBase_clear, mieAbsorptionBase_rain, rainStrength);
    #endif
}

float safeacos(const in float x) {
    return acos(clamp(x, -1.0, 1.0));
}

float GetScaledSkyHeight(const in float worldY) {
    float scaleY = (worldY - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
    scaleY = clamp(scaleY, 0.004, 0.996);
    return groundRadiusMM + scaleY * (atmosphereRadiusMM - groundRadiusMM);
}

vec3 GetAtmospherePosition(const in vec3 worldPos) {
    vec3 atmosPos = worldPos - vec3(cameraPosition.x, SEA_LEVEL, cameraPosition.z);
    atmosPos /= ATMOSPHERE_LEVEL - SEA_LEVEL;
    atmosPos.y = clamp(atmosPos.y, 0.004, 0.996);
    atmosPos *= atmosphereRadiusMM - groundRadiusMM;
    return atmosPos + vec3(0.0, groundRadiusMM, 0.0);
}

float GetAtmosphereElevation(const in vec3 worldPos) {
    vec3 atmosPos = GetAtmospherePosition(worldPos);
    return length(atmosPos) - groundRadiusMM;
}

vec3 getAtmosLUT_UV(const in float sunCosZenithAngle, const in float elevation) {
    vec3 uv;
    uv.x = 0.5 + 0.5*sunCosZenithAngle;
    uv.y = (elevation - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM);

    #ifdef WORLD_END
        uv.z = 1.0;
    #else
        uv.z = (0.0 + rainStrength) / 5.0;
    #endif

    return uv;
}
