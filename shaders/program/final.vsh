#define RENDER_VERTEX
#define RENDER_FINAL

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

#ifndef IRIS_FEATURE_SSBO
    flat out float sceneExposure;
#endif

#ifdef DEBUG_EXPOSURE_METERS
    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        flat out int luminanceLod;
        flat out float averageLuminance;
        flat out float EV100;
    #endif
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float screenBrightness;
uniform int heldBlockLightValue;
uniform float viewWidth;
uniform float viewHeight;
uniform int worldTime;

uniform float rainStrength;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int moonPhase;

uniform float blindness;

#ifdef DEBUG_EXPOSURE_METERS
    uniform float nightVision;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif
#endif

#ifdef BLOOM_ENABLED
    flat out int bloomTileCount;

    uniform sampler2D BUFFER_HDR;

    #include "/lib/camera/bloom.glsl"
#endif


#ifdef DEBUG_EXPOSURE_METERS
    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #ifdef BLOOM_ENABLED
        bloomTileCount = GetBloomTileCount();
    #endif

    #ifdef DEBUG_EXPOSURE_METERS
        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            luminanceLod = GetLuminanceLod();
        #endif

        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            averageLuminance = GetAverageLuminance();
            //float keyValue = GetExposureKeyValue(averageLuminance);
            EV100 = GetEV100(averageLuminance);// - keyValue;
        #endif
    #endif
}
