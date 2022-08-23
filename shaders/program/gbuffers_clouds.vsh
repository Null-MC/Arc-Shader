#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_CLOUDS

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
out vec4 glcolor;
out vec3 viewPos;
out vec3 localPos;
flat out float exposure;
flat out vec2 skyLightLevels;

//uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
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
#endif

uniform float rainStrength;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;

#ifdef IS_OPTIFINE
    uniform mat4 gbufferModelView;
    uniform int worldTime;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    //viewPos = (gbufferModelView * gl_Vertex).xyz;
    //gl_Position = gbufferProjection * vec4(viewPos, 1.0);
    gl_Position = ftransform();
    viewPos = (gbufferProjectionInverse * gl_Position).xyz;
    localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    skyLightLevels = GetSkyLightLevels();

    exposure = GetExposure();
}
