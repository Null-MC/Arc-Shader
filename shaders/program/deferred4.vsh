#define RENDER_VERTEX
#define RENDER_DEFERRED
#define RENDER_AO

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

// #ifndef IRIS_FEATURE_SSBO
//     flat out float sceneExposure;

//     #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
//         uniform sampler2D BUFFER_HDR_PREVIOUS;

//         uniform float viewWidth;
//         uniform float viewHeight;
//     #endif

//     #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
//         uniform ivec2 eyeBrightness;
//     #endif

//     #include "/lib/camera/exposure.glsl"
// #endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    //#ifndef IRIS_FEATURE_SSBO
    //    exposure = GetExposure();
    //#endif
}
