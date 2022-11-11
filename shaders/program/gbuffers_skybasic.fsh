#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

flat in vec3 sunTransmittanceEye;
flat in vec3 sunColor;
flat in vec3 moonColor;
flat in float exposure;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float near;
uniform float far;
    
uniform int isEyeInWater;
uniform float rainStrength;
uniform float wetness;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform int moonPhase;

#ifdef IS_OPTIFINE
    //uniform float eyeHumidity;
    uniform int worldTime;
#endif
    //uniform float eyeHumidity;

// #if ATMOSPHERE_TYPE == ATMOSPHERE_TYPE_FANCY
//     uniform sampler2D noisetex;

//     uniform mat4 gbufferModelViewInverse;
//     uniform float frameTimeCounter;
//     uniform float eyeAltitude;

//     #include "/lib/world/atmosphere.glsl"
// #endif

//#include "/lib/sampling/bayer.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/world/scattering.glsl"

/* RENDERTARGETS: 4,6 */
out vec3 outColor0;
out float outColor1;


void main() {
    vec3 clipPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0) * 2.0 - 1.0;
    vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

    vec3 viewDir = normalize(viewPos);
    vec3 color = GetVanillaSkyLuminance(viewDir);

    #ifndef VL_ENABLED
        vec2 skyLightLevels = GetSkyLightLevels();
        vec3 sunColorFinal = sunTransmittanceEye * sunColor;
        vec3 lightColor = GetVanillaSkyScattering(viewDir, skyLightLevels, sunColorFinal, moonColor);

        vec3 fogColorLinear = RGBToLinear(fogColor);
        color += lightColor * fogColorLinear;
    #endif

    outColor1 = log2(luminance(color) + EPSILON);
    outColor0 = clamp(color * exposure, vec3(0.0), vec3(65000));
}
