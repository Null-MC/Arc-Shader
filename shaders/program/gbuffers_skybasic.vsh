#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

flat out vec3 sunTransmittanceEye;
flat out vec3 sunColor;
flat out vec3 moonColor;
flat out float exposure;

uniform sampler2D colortex9;

uniform float screenBrightness;
uniform float eyeAltitude;
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
#include "/lib/sky/sun.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();

    vec2 skyLightLevels = GetSkyLightLevels();
    vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
    moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);
    sunColor = GetSunLuxColor();

    sunTransmittanceEye = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);

    exposure = GetExposure();
}
