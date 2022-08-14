#extension GL_ARB_texture_query_levels : enable

#define RENDER_VERTEX
#define RENDER_FINAL

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    flat out int luminanceLod;
    flat out float averageLuminance;
    flat out float EV100;

    uniform sampler2D BUFFER_HDR_PREVIOUS;

    uniform float viewWidth;
    uniform float viewHeight;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
#endif

uniform float screenBrightness;
uniform int heldBlockLightValue;
uniform float blindness;

uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int moonPhase;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef BLOOM_ENABLED
    flat out int bloomTileCount;

    uniform sampler2D BUFFER_HDR;

    #include "/lib/camera/bloom.glsl"
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #ifdef BLOOM_ENABLED
        bloomTileCount = GetBloomTileCount();
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        luminanceLod = GetLuminanceLod();
    #endif

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        averageLuminance = GetAverageLuminance();
        EV100 = GetEV100(averageLuminance);
    #endif
}
