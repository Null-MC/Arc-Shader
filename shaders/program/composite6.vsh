#define RENDER_VERTEX
#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_BLOOM_DOWNSCALE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out int tileCount;

#ifndef IRIS_FEATURE_SSBO
    flat out float sceneExposure;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;

        uniform float rainStrength;
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;
        uniform int moonPhase;
    #endif
#endif

uniform sampler2D BUFFER_HDR;

uniform int heldBlockLightValue;
uniform float screenBrightness;
uniform float viewWidth;
uniform float viewHeight;

uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#include "/lib/camera/bloom.glsl"

#ifndef IRIS_FEATURE_SSBO
    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        #include "/lib/lighting/blackbody.glsl"
        #include "/lib/world/sky.glsl"
    #endif

    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    tileCount = GetBloomTileCount();

    #ifndef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();
    #endif
}
