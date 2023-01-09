#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

flat out vec3 sunTransmittanceEye;
flat out vec3 moonTransmittanceEye;
flat out vec3 sunColor;
flat out vec3 moonColor;
flat out float exposure;

#if SHADER_PLATFORM == PLATFORM_IRIS
    uniform sampler3D texSunTransmittance;
#else
    uniform sampler3D colortex9;
#endif

uniform float screenBrightness;
uniform float eyeAltitude;
uniform float wetness;

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

uniform int renderStage;
uniform float nightVision;
uniform float blindness;

#if SHADER_PLATFORM == PLATFORM_OPTIFINE
    uniform mat4 gbufferModelView;
    uniform int worldTime;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/celestial_position.glsl"
#include "/lib/sky/celestial_color.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    if (renderStage == MC_RENDER_STAGE_STARS) {
        gl_Position = vec4(10.0);
        return;
    }

    gl_Position = ftransform();

    sunColor = GetSunLuxColor();
    moonColor = GetMoonLuxColor();// * GetMoonPhaseLevel();

    vec2 skyLightLevels = GetSkyLightLevels();
    
    #if SHADER_PLATFORM == PLATFORM_IRIS
        sunTransmittanceEye = GetSunTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.x);
        moonTransmittanceEye = GetMoonTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.y);
    #else
        sunTransmittanceEye = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);
        moonTransmittanceEye = GetMoonTransmittance(colortex9, eyeAltitude, skyLightLevels.y);
    #endif

    exposure = GetExposure();
}
