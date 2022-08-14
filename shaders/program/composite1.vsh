#extension GL_ARB_texture_query_levels : enable

#define RENDER_VERTEX
#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_BLOOM_DOWNSCALE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out int tileCount;
flat out float exposure;

uniform sampler2D BUFFER_HDR;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;

    uniform float viewWidth;
    uniform float viewHeight;
#endif

uniform int heldBlockLightValue;
uniform float screenBrightness;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;

    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;
    
    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
#endif

#include "/lib/camera/bloom.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    tileCount = GetBloomTileCount();

    exposure = GetExposure();
}
