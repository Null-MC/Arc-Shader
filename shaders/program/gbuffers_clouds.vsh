#extension GL_ARB_texture_query_levels : enable

#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_CLOUDS

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
out vec4 glcolor;
flat out float exposure;

uniform float screenBrightness;
uniform float blindness;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    
    uniform float viewWidth;
    uniform float viewHeight;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
    uniform int heldBlockLightValue;

    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform int moonPhase;

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
#endif

#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    exposure = GetExposure();
}
