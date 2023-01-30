#define RENDER_DEFERRED_FINAL
#define RENDER_DEFERRED
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out vec3 blockLightColor;

#ifndef IRIS_FEATURE_SSBO
    flat out float sceneExposure;
#endif

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
    flat out vec2 skyLightLevels;
    flat out vec3 sunTransmittanceEye;

    #ifdef WORLD_MOON_ENABLED
        flat out vec3 moonColor;
        flat out vec3 moonTransmittanceEye;
    #endif

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
    #else
        uniform sampler3D colortex12;
    #endif

    uniform vec3 skyColor;
    uniform float wetness;
    uniform float eyeAltitude;
#endif

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float screenBrightness;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform float rainStrength;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int moonPhase;
uniform int worldTime;

//uniform int isEyeInWater;
uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#include "/lib/lighting/blackbody.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"
#endif

#ifndef IRIS_FEATURE_SSBO
    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #ifdef SKY_ENABLED
        skyLightLevels = GetSkyLightLevels();
        float eyeElevation = GetScaledSkyHeight(eyeAltitude);

        sunColor = GetSunLuxColor();

        #if SHADER_PLATFORM == PLATFORM_IRIS
            sunTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.x);
        #else
            sunTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.x);
        #endif

        #ifdef WORLD_MOON_ENABLED
            moonColor = GetMoonLuxColor();// * GetMoonPhaseLevel();

            #if SHADER_PLATFORM == PLATFORM_IRIS
                moonTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.y);
            #else
                moonTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.y);
            #endif
        #endif
    #endif

    blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

    #ifndef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();
    #endif
}