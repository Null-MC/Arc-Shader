#define earthRadius 6371000.0
#define cloudSpeed 0.02
#define cloudHeight 1600.0
#define cloudThickness 500.0
#define cloudDensity 0.03
#define cloudShadowingSteps 12 // Higher is a better result with shading on clouds.

#define cloudMinHeight cloudHeight
#define cloudMaxHeight (cloudThickness + cloudMinHeight)
#define volumetricCloudSteps 16 // Higher is a better result with rendering of clouds.
#define rayleighCoeff (vec3(0.27, 0.5, 1.0) * 1e-5) // Not really correct
#define mieCoeff vec3(0.5e-6) // Not really correct

#define d02(x) (abs(x) + 1e-3)

const float sunBrightness = 3.0;
const vec3 totalCoeff = rayleighCoeff + mieCoeff;
const float pi = acos(-1.0);
const float rPi = rcp(pi);
const float hPi = pi * 0.5;
const float rLOG2 = rcp(log(2.0));


float hgPhase(const in float x, const in float g) {
    float g2 = g*g;
    return 0.25 * ((1.0 - g2) * pow(1.0 + g2 - 2.0*g*x, -1.5));
}

vec2 rsi(const in vec3 position, const in vec3 direction, const in float radius) {
    float PoD = dot(position, direction);
    float radiusSquared = radius * radius;

    float delta = PoD * PoD + radiusSquared - dot(position, position);
    if (delta < 0.0) return vec2(-1.0);

    delta = sqrt(delta);
    return -PoD + vec2(-delta, delta);
}

float Get3DNoise(const in vec3 pos) {
    float p = floor(pos.z);
    float f = pos.z - p;
    
    const float invNoiseRes = rcp(64.0);
    const float zStretch = 17.0 * invNoiseRes;
    
    vec2 coord = pos.xy * invNoiseRes + (p * zStretch);
    
    vec2 noise;
    noise.x = texture(noisetex, coord).r;
    noise.y = texture(noisetex, coord + zStretch).r;
    
    return mix(noise.x, noise.y, f);
}

float phase2Lobes(const in float x) {
    const float m = 0.6;
    const float gm = 0.8;
    
    float lobe1 = hgPhase(x, 0.8 * gm);
    float lobe2 = hgPhase(x, -0.5 * gm);
    
    return mix(lobe2, lobe1, m);
}

float calculateScatterIntergral(const in float opticalDepth, const in float coeff) {
    float a = -coeff * rLOG2;
    float c =  rcp(coeff);

    return exp2(a * opticalDepth) * -c + c;
}

// vec3 calculateScatterIntergral(const in float opticalDepth, const in vec3 coeff) {
//     vec3 a = -coeff * rLOG2;
//     vec3 c =  rcp(coeff);

//     return exp2(a * opticalDepth) * -c + c;
// }

vec3 scatter(vec3 coeff, float depth) {
    return coeff * depth;
}

vec3 absorb(vec3 coeff, float depth) {
    return exp2(scatter(coeff, -depth));
}

float calcParticleThickness(const in float depth) {
    return 100000.0 * rcp(max(depth * 2.0 + 0.01, 0.01));   
}

float calcParticleThicknessConst(const in float depth) {
    return 100000.0 / max(depth * 2.0 - 0.01, 0.01);   
}

float powder(const in float od) {
    return 1.0 - exp2(-od * 2.0);
}

vec3 calcAtmosphericScatterTop(const in vec3 sunVector) {
    const float ln2 = log(2.0);
    
    float lDotU = dot(sunVector, vec3(0.0, 1.0, 0.0));
    
    float opticalDepth = calcParticleThicknessConst(1.0);
    float opticalDepthLight = calcParticleThickness(lDotU);
    
    vec3 scatterView = scatter(totalCoeff, opticalDepth);
    vec3 absorbView = absorb(totalCoeff, opticalDepth);
    
    vec3 scatterLight = scatter(totalCoeff, opticalDepthLight);
    vec3 absorbLight = absorb(totalCoeff, opticalDepthLight);
    
    vec3 absorbSun = d02(absorbLight - absorbView) / d02((scatterLight - scatterView) * ln2);
    
    vec3 mieScatter = scatter(mieCoeff, opticalDepth) * 0.25;
    vec3 rayleighScatter = scatter(rayleighCoeff, opticalDepth) * 0.375;
    
    vec3 scatterSun = mieScatter + rayleighScatter;
    
    return (scatterSun * absorbSun) * sunBrightness;
}

float getClouds(vec3 p) {
    p = vec3(p.x, length(p + vec3(0.0, earthRadius, 0.0)) - earthRadius, p.z);
    
    if (p.y < cloudMinHeight || p.y > cloudMaxHeight) return 0.0;
    
    float time = (frameTimeCounter / 3.6) * cloudSpeed;
    vec3 movement = vec3(time, 0.0, time);
    
    vec3 cloudCoord = (p * 0.001) + movement;
    
    float noise = Get3DNoise(cloudCoord) * 0.5;
          noise += Get3DNoise(cloudCoord * 2.0 + movement) * 0.25;
          noise += Get3DNoise(cloudCoord * 7.0 - movement) * 0.125;
          noise += Get3DNoise((cloudCoord + movement) * 16.0) * 0.0625;
    
    const float top = 0.004;
    const float bottom = 0.01;
    
    float horizonHeight = p.y - cloudMinHeight;
    float treshHold = (1.0 - exp2(-bottom * horizonHeight)) * exp2(-top * horizonHeight);
    
    float clouds = smoothstep(0.55, 0.6, noise);
    return clouds * treshHold * cloudDensity;
}

float getSunVisibility(const in vec3 p, const in vec3 sunVector) {
    const int steps = cloudShadowingSteps;
    const float rSteps = cloudThickness / float(steps);
    
    vec3 increment = sunVector * rSteps;
    vec3 position = increment * 0.5 + p;
    
    float transmittance = 0.0;
    
    for (int i = 0; i < steps; i++, position += increment) {
        transmittance += getClouds(position);
    }
    
    return exp2(-transmittance * rSteps);
}

vec3 getVolumetricCloudsScattering(float opticalDepth, float phase, vec3 p, vec3 sunColor, vec3 skyLight, const in vec3 sunVector) {
    float intergal = calculateScatterIntergral(opticalDepth, 1.11);
    
    float beersPowder = powder(opticalDepth * log(2.0));
    
    vec3 sunlighting = (sunColor * getSunVisibility(p, sunVector) * beersPowder) * phase * hPi * sunBrightness;
    vec3 skylighting = skyLight * 0.25 * rPi;
    
    return (sunlighting + skylighting) * intergal * pi;
}

void calculateVolumetricClouds(inout vec3 color, const in vec3 worldVector, const in vec3 sunVector, float dither, vec3 sunColor) {
	const int steps = volumetricCloudSteps;
    const float iSteps = rcp(steps);
        
    float bottomSphere = rsi(vec3(0.0, 1.0, 0.0) * earthRadius, worldVector, earthRadius + cloudMinHeight).y;
    float topSphere = rsi(vec3(0.0, 1.0, 0.0) * earthRadius, worldVector, earthRadius + cloudMaxHeight).y;
    
    vec3 startPosition = worldVector * bottomSphere;
    vec3 endPosition = worldVector * topSphere;
    
    vec3 increment = (endPosition - startPosition) * iSteps;
    vec3 cloudPosition = increment * dither + startPosition;
    
    float stepLength = length(increment);
    
    vec3 scattering = vec3(0.0);
    float transmittance = 1.0;
    
    float lDotW = dot(sunVector, worldVector);
    float phase = phase2Lobes(lDotW);
    
    vec3 skyLight = calcAtmosphericScatterTop(sunVector);
    
    for (int i = 0; i < steps; i++, cloudPosition += increment) {
        float opticalDepth = getClouds(cloudPosition) * stepLength;
        
        if (opticalDepth <= 0.0) continue;
        
		scattering += getVolumetricCloudsScattering(opticalDepth, phase, cloudPosition, sunColor, skyLight, sunVector) * transmittance;
        transmittance *= exp2(-opticalDepth);
    }
    
    color = mix(color * transmittance + scattering, color, saturate(length(startPosition) * 0.00001));
}