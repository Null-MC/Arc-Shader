// These are per megameter.
const float groundRadiusMM = 6.360;
const float atmosphereRadiusMM = 6.460;

const vec3 ozoneAbsorptionBase = vec3(0.650, 1.881, 0.085);
const vec3 rayleighScatteringBase = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase = 0.0;
const float mieScatteringBase = 3.996;
const float mieAbsorptionBase = 4.4;


float safeacos(const in float x) {
    return acos(clamp(x, -1.0, 1.0));
}
