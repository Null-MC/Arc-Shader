// These are per megameter.
const float groundRadiusMM = 6.360;
const float atmosphereRadiusMM = 6.460;

// const vec3 ozoneAbsorptionBase = vec3(0.650, 1.881, 0.085);
// const vec3 rayleighScatteringBase = vec3(5.802, 13.558, 33.1);
// const float rayleighAbsorptionBase = 0.0;
// const float mieScatteringBase = 3.996;
// const float mieAbsorptionBase = 4.4;

const vec3 ozoneAbsorptionBase_clear = vec3(0.650, 1.881, 0.085);
const vec3 rayleighScatteringBase_clear = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase_clear = 0.0;
const float mieScatteringBase_clear = 3.996;
const float mieAbsorptionBase_clear = 4.4;

const vec3 ozoneAbsorptionBase_rain = vec3(0.650, 1.881, 0.085) * 2.0;
const vec3 rayleighScatteringBase_rain = vec3(5.802, 13.558, 33.1) * 8.0;
const float rayleighAbsorptionBase_rain = 16.0;
const float mieScatteringBase_rain = 3.996 * 16.0;
const float mieAbsorptionBase_rain = 4.4 * 80.0;


vec3 GetOzoneAbsorptionBase() {
    return mix(ozoneAbsorptionBase_clear, ozoneAbsorptionBase_rain, wetness);
}

vec3 GetRayleighScatteringBase() {
    return mix(rayleighScatteringBase_clear, rayleighScatteringBase_rain, wetness);
}

float GetRayleighAbsorptionBase() {
    return mix(rayleighAbsorptionBase_clear, rayleighAbsorptionBase_rain, wetness);
}

float GetMieScatteringBase() {
    return mix(mieScatteringBase_clear, mieScatteringBase_rain, wetness);
}

float GetMieAbsorptionBase() {
    return mix(mieAbsorptionBase_clear, mieAbsorptionBase_rain, wetness);
}

float safeacos(const in float x) {
    return acos(clamp(x, -1.0, 1.0));
}
