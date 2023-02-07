#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
out vec4 glcolor;

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

    #ifdef WORLD_MOON_ENABLED
        flat out vec3 skyMoonColor;
        flat out vec3 moonTransmittanceEye;
    #endif
#endif

uniform mat4 gbufferModelViewInverse;
uniform int renderStage;
uniform vec3 cameraPosition;
uniform float screenBrightness;
uniform float eyeAltitude;
uniform float wetness;

uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;
uniform int worldTime;

uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifndef IRIS_FEATURE_SSBO
    #ifdef IS_IRIS
        uniform sampler3D texSunTransmittance;
    #else
        uniform sampler3D colortex12;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    #ifdef SUN_FANCY
        if (renderStage == MC_RENDER_STAGE_SUN) {
            gl_Position = vec4(10.0);
            return;
        }
    #endif

    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    #ifndef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();

        vec2 skyLightLevels = GetSkyLightLevels();
        float eyeElevation = GetScaledSkyHeight(eyeAltitude);
        
        skySunColor = GetSunColor();

        #ifdef IS_IRIS
            sunTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.x);
        #else
            sunTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.x);
        #endif

        #ifdef WORLD_MOON_ENABLED
            skyMoonColor = GetMoonColor();

            #ifdef IS_IRIS
                moonTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.y);
            #else
                moonTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.y);
            #endif
        #endif
    #endif
}
