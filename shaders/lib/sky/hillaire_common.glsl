// These are per megameter.
const float groundRadiusMM = 9.360;
const float atmosphereRadiusMM = 9.460;

const vec3 ozoneAbsorptionBase_rain = vec3(0.650, 1.381, 0.576);
const vec3 rayleighScatteringBase_rain = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase_rain = 16.0;
const float mieScatteringBase_rain = 3.996 * 32.0;
const float mieAbsorptionBase_rain = 4.4 * 8.0;

const vec3 ozoneAbsorptionBase_clear = vec3(0.650, 1.381, 0.576);
const vec3 rayleighScatteringBase_clear = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase_clear = 0.0;
const float mieScatteringBase_clear = 3.996;
const float mieAbsorptionBase_clear = 4.4;


vec3 GetOzoneAbsorptionBase() {
    return mix(ozoneAbsorptionBase_clear, ozoneAbsorptionBase_rain, rainStrength);
}

vec3 GetRayleighScatteringBase() {
    return mix(rayleighScatteringBase_clear, rayleighScatteringBase_rain, rainStrength);
}

float GetRayleighAbsorptionBase() {
    return mix(rayleighAbsorptionBase_clear, rayleighAbsorptionBase_rain, rainStrength);
}

float GetMieScatteringBase() {
    return mix(mieScatteringBase_clear, mieScatteringBase_rain, rainStrength);
}

float GetMieAbsorptionBase() {
    return mix(mieAbsorptionBase_clear, mieAbsorptionBase_rain, rainStrength);
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
