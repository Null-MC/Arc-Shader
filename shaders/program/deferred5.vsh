#define RENDER_DEFERRED_FINAL
#define RENDER_DEFERRED
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out float exposure;
flat out vec3 blockLightColor;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;

    uniform float viewWidth;
    uniform float viewHeight;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
#endif

#ifdef SKY_ENABLED
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec2 skyLightLevels;
    flat out vec3 sunTransmittanceEye;
    flat out vec3 moonTransmittanceEye;

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
    #else
        uniform sampler3D colortex12;
    #endif

    uniform vec3 skyColor;
    uniform float wetness;
    uniform float eyeAltitude;

    #ifdef SHADOW_ENABLED
        //flat out vec3 skyLightColor;

        uniform vec3 shadowLightPosition;
    #endif
#endif

uniform mat4 gbufferModelView;
uniform float screenBrightness;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int moonPhase;

//uniform int isEyeInWater;
uniform float nightVision;
uniform float blindness;

#if SHADER_PLATFORM == PLATFORM_OPTIFINE
    uniform int worldTime;
//#else
//    uniform mat4 gbufferModelView;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#include "/lib/lighting/blackbody.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/celestial_position.glsl"
    #include "/lib/sky/celestial_color.glsl"
    #include "/lib/world/sky.glsl"
#endif

#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #ifdef SKY_ENABLED
        sunColor = GetSunLuxColor();
        moonColor = GetMoonLuxColor();// * GetMoonPhaseLevel();

        skyLightLevels = GetSkyLightLevels();

        #if SHADER_PLATFORM == PLATFORM_IRIS
            sunTransmittanceEye = GetSunTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.x);
            moonTransmittanceEye = GetMoonTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.y);
        #else
            sunTransmittanceEye = GetSunTransmittance(colortex12, eyeAltitude, skyLightLevels.x);
            moonTransmittanceEye = GetMoonTransmittance(colortex12, eyeAltitude, skyLightLevels.y);
        #endif
    #endif

    blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

    exposure = GetExposure();
}
