#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

#ifndef IRIS_FEATURE_SSBO
    flat out float sceneExposure;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
        
        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
        uniform int heldBlockLightValue;
    #endif

    flat out vec3 skySunColor;
    flat out vec3 sunTransmittanceEye;

    // #ifdef WORLD_MOON_ENABLED
    //     flat out vec3 skyMoonColor;
    //     flat out vec3 moonTransmittanceEye;
    // #endif

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
    #else
        uniform sampler3D colortex12;
    #endif
#endif

uniform vec3 cameraPosition;
uniform float screenBrightness;
uniform float eyeAltitude;
uniform float wetness;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform int moonPhase;
uniform int worldTime;

uniform int renderStage;
uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/hillaire_common.glsl"
#include "/lib/celestial/position.glsl"
#include "/lib/celestial/transmittance.glsl"
#include "/lib/world/sky.glsl"

#ifndef IRIS_FEATURE_SSBO
    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    if (renderStage == MC_RENDER_STAGE_STARS) {
        gl_Position = vec4(10.0);
        return;
    }

    gl_Position = ftransform();

    #ifndef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();

        vec2 skyLightLevels = GetSkyLightLevels();
        float eyeElevation = GetScaledSkyHeight(eyeAltitude);
        
        skySunColor = GetSunColor();

        #if SHADER_PLATFORM == PLATFORM_IRIS
            sunTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.x);
        #else
            sunTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.x);
        #endif

        // #ifdef WORLD_MOON_ENABLED
        //     skyMoonColor = GetMoonColor();

        //     #if SHADER_PLATFORM == PLATFORM_IRIS
        //         moonTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.y);
        //     #else
        //         moonTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.y);
        //     #endif
        // #endif
    #endif
}
