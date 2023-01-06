#define RENDER_PREPARE
#define RENDER_FRAG
//#define RENDER_SKY_LUT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform float rainStrength;
uniform int moonPhase;

#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/sun_moon.glsl"
#include "/lib/sky/hillaire_common.glsl"
#include "/lib/sky/hillaire.glsl"


/* RENDERTARGETS: 15 */
layout(location = 0) out vec3 outColor0;

const int numScatteringSteps = 32;

vec3 raymarchScattering(vec3 pos, vec3 rayDir, vec3 sunDir, float tMax, float numSteps) {
    float cosTheta = dot(rayDir, sunDir);
    
    float miePhaseValue = getMiePhase(cosTheta);
    float rayleighPhaseValue = getRayleighPhase(-cosTheta);
    
    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float t = 0.0;
    for (float i = 0.0; i < numSteps; i += 1.0) {
        float newT = ((i + 0.3)/numSteps)*tMax;
        float dt = newT - t;
        t = newT;
        
        vec3 newPos = pos + t*rayDir;
        
        vec3 rayleighScattering, extinction;
        float mieScattering;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);
        
        vec3 sampleTransmittance = exp(-dt*extinction);

        vec3 sunTransmittance = getValFromTLUT(colortex2, newPos, sunDir);
        vec3 psiMS = getValFromMultiScattLUT(colortex1, newPos, sunDir);
        
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
    
    float height = (cameraPosition.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
    height = groundRadiusMM + height * (atmosphereRadiusMM - groundRadiusMM);

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        vec3 up = gbufferModelView[1].xyz;
    #else
        vec3 up = normalize(upPosition);
    #endif

    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height) - 0.5*PI;
    float altitudeAngle = adjV*0.5*PI - horizonAngle;
    
    float cosAltitude = cos(altitudeAngle);
    vec3 rayDir = vec3(cosAltitude*sin(azimuthAngle), sin(altitudeAngle), -cosAltitude*cos(azimuthAngle));
    
    //float sunAltitude = (0.5*PI) - acos(dot(getSunDir(iTime), up));
    //vec3 sunDir = vec3(0.0, sin(sunAltitude), -cos(sunAltitude));
    vec3 sunDir = mat3(gbufferModelViewInverse) * GetSunDir();
    
    vec3 skyViewPos = vec3(0.0, height, 0.0);

    float atmoDist = rayIntersectSphere(skyViewPos, rayDir, atmosphereRadiusMM);
    float groundDist = rayIntersectSphere(skyViewPos, rayDir, groundRadiusMM);
    float tMax = (groundDist < 0.0) ? atmoDist : groundDist;
    outColor0 = raymarchScattering(skyViewPos, rayDir, sunDir, tMax, float(numScatteringSteps));
}
