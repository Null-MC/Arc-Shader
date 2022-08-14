#extension GL_ARB_texture_query_levels : enable

#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec3 starData;
flat out float sunLightLevel;
flat out vec3 sunColor;
flat out vec3 moonColor;
flat out float exposure;

uniform float screenBrightness;
uniform float blindness;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    
    uniform float viewWidth;
    uniform float viewHeight;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
    uniform int heldBlockLightValue;
#endif

uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int moonPhase;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef IS_OPTIFINE
    uniform mat4 gbufferModelView;
    uniform int worldTime;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();

    float starFactor = pow(gl_Color.r, GAMMA) * float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);

    float starTemp = mix(5300, 6000, starFactor);
    starData = blackbody(starTemp) * starFactor * StarLumen;

    vec2 skyLightLevels = GetSkyLightLevels();
    vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
    sunColor = GetSunLightLuxColor(skyLightTemps.x, skyLightLevels.x);
    moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);
    sunLightLevel = GetSunLightLevel(skyLightLevels.x);

    exposure = GetExposure();
}
