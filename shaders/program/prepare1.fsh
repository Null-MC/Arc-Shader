#define RENDER_PREPARE_SKY_LUT
#define RENDER_PREPARE
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
flat in vec3 localSunDir;

uniform sampler3D TEX_SUN_TRANSMIT;
uniform sampler3D TEX_MULTI_SCATTER;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float rainStrength;
uniform float wetness;

#include "/lib/sky/hillaire_common.glsl"
#include "/lib/sky/hillaire_render.glsl"
#include "/lib/sky/hillaire.glsl"


/* RENDERTARGETS: 7 */
layout(location = 0) out vec3 outColor0;

vec3 raymarchScattering(const in vec3 pos, const in vec3 rayDir, const in vec3 sunDir, const in float tMax) {
    const int numScatteringSteps = 32;

    float cosTheta = dot(rayDir, sunDir);
    float miePhaseValue = getMiePhase(cosTheta);
    float rayleighPhaseValue = getRayleighPhase(-cosTheta);
    
    float t = 0.0;
    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    for (float i = 0.0; i < numScatteringSteps; i += 1.0) {
        float newT = ((i + 0.3) / numScatteringSteps) * tMax;
        float dt = newT - t;
        t = newT;
        
        vec3 newPos = pos + t*rayDir;
        
        vec3 rayleighScattering, extinction;
        float mieScattering;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);
        
        vec3 sampleTransmittance = exp(-dt*extinction);

        vec3 sunTransmittance = getValFromTLUT(newPos, sunDir);
        vec3 psiMS = getValFromMultiScattLUT(newPos, sunDir);
        
        vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue*sunTransmittance + psiMS);
        vec3 mieInScattering = mieScattering * (miePhaseValue*sunTransmittance + psiMS);
        vec3 inScattering = (rayleighInScattering + mieInScattering);

        // Integrated scattering within path segment.
        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral * transmittance;
        
        transmittance *= sampleTransmittance;
    }

    return lum;
}

void main() {
    float azimuthAngle = (texcoord.x - 0.5) * TAU;

    // Non-linear mapping of altitude. See Section 5.3 of the paper.
    float adjV;
    if (texcoord.y < 0.5) {
        float coord = 1.0 - 2.0*texcoord.y;
        adjV = -coord*coord;
    } else {
        float coord = texcoord.y*2.0 - 1.0;
        adjV = coord*coord;
    }
    
    float height = GetScaledSkyHeight(cameraPosition.y);
    vec3 skyViewPos = vec3(0.0, height, 0.0);

    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height) - 0.5*PI;
    float altitudeAngle = adjV*0.5*PI - horizonAngle;
    
    float cosAltitude = cos(altitudeAngle);
    vec3 rayDir = vec3(cosAltitude*sin(azimuthAngle), sin(altitudeAngle), -cosAltitude*cos(azimuthAngle));
    
    float atmoDist = rayIntersectSphere(skyViewPos, rayDir, atmosphereRadiusMM);
    float groundDist = rayIntersectSphere(skyViewPos, rayDir, groundRadiusMM);
    float tMax = (groundDist < 0.0) ? atmoDist : groundDist;

    vec3 sunDir = normalize(localSunDir);
    outColor0 = raymarchScattering(skyViewPos, rayDir, sunDir, tMax);
}
