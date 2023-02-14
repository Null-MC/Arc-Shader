// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(const in vec3 ro, const in vec3 rd, const in float rad) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad*rad;
    if (c > 0.0f && b > 0.0) return -1.0;

    float discr = b*b - c;
    if (discr < 0.0) return -1.0;

    // Special case: inside sphere, use far discriminant
    if (discr > b*b) return (-b + sqrt(discr));
    return -b - sqrt(discr);
}

float getSunAltitude(const in float time) {
    const float periodSec = 120.0;
    const float halfPeriod = periodSec / 2.0;
    const float sunriseShift = 0.1;
    float cyclePoint = (1.0 - abs((mod(time,periodSec)-halfPeriod)/halfPeriod));
    cyclePoint = (cyclePoint * (1.0 + sunriseShift)) - sunriseShift;
    return (0.5*PI) * cyclePoint;
}

vec3 getSunDir(const in float time) {
    float altitude = getSunAltitude(time);
    return normalize(vec3(0.0, sin(altitude), -cos(altitude)));
}

float getMiePhase(const in float cosTheta) {
    const float g = 0.8;
    const float scale = 3.0 / (8.0*PI);
    
    float num = (1.0 - g*g) * (1.0 + cosTheta*cosTheta);
    float denom = (2.0 + g*g) * pow((1.0 + g*g - 2.0*g*cosTheta), 1.5);
    
    return scale*num / denom;
}

float getRayleighPhase(const in float cosTheta) {
    const float k = 3.0 / (16.0*PI);
    return k * (1.0 + cosTheta*cosTheta);
}

void getScatteringValues(const in vec3 pos, const in float density, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction) {
    float altitudeKM = (length(pos) - groundRadiusMM) * 1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM / 8.0) * density;
    float mieDensity = exp(-altitudeKM / 1.2) * density;
    
    rayleighScattering = GetRayleighScatteringBase() * rayleighDensity;
    float rayleighAbsorption = GetRayleighAbsorptionBase() * rayleighDensity;
    
    mieScattering = GetMieScatteringBase() * mieDensity;
    float mieAbsorption = GetMieAbsorptionBase() * mieDensity;
    
    vec3 ozoneAbsorption = GetOzoneAbsorptionBase() * max(0.0, 1.0 - abs(altitudeKM - 25.0) / 15.0);
    
    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}

void getScatteringValues(const in vec3 pos, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction) {
    getScatteringValues(pos, 1.0, rayleighScattering, mieScattering, extinction);
}