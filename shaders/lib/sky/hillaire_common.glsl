// These are per megameter.
const float groundRadiusMM = 9.360;
const float atmosphereRadiusMM = 9.460;

const vec3 ozoneAbsorptionBase_rain = vec3(0.650, 0.681, 0.076) * 3.6;
const vec3 rayleighScatteringBase_rain = vec3(9.0, 12.0, 16.0) * 6.0;
const float rayleighAbsorptionBase_rain = 40.0;
const float mieScatteringBase_rain = 3.996 * 12.0;
const float mieAbsorptionBase_rain = 4.4 * 12.0;

const vec3 ozoneAbsorptionBase_clear = vec3(0.650, 1.681, 0.076);
const vec3 rayleighScatteringBase_clear = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase_clear = 1.0;
const float mieScatteringBase_clear = 3.996 * 1.6;
const float mieAbsorptionBase_clear = 4.4 * 3.0;


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
