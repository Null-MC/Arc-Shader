#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
out vec4 glcolor;
//flat out vec2 skyLightLevels;
flat out vec3 sunTransmittance;
flat out float sunLightLevel;
flat out float moonLightLevel;
//flat out vec3 sunLightLumColor;
flat out vec3 moonLightLumColor;
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

uniform float rainStrength;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
    uniform int heldBlockLightValue;
#endif

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
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    exposure = GetExposure();

    vec2 skyLightLevels = GetSkyLightLevels();

    sunTransmittance = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);
    sunLightLevel = luminance(sunTransmittance);

    vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);
    //sunLightLevel = GetSunLightLevel(skyLightLevels.x);
    moonLightLevel = GetMoonLightLevel(skyLightLevels.y);
    //sunLightLumColor = GetSunLightColor(skyLightTemp.x, skyLightLevels.x) * sunLumen;
    moonLightLumColor = GetMoonLightColor(skyLightTemp.y, skyLightLevels.y) * moonLumen;
}
