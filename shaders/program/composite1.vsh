#define RENDER_COMPOSITE_FINAL
#define RENDER_COMPOSITE
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

#ifndef IRIS_FEATURE_SSBO
    flat out float sceneExposure;
    
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
        flat out vec2 skyLightLevels;

        flat out vec3 skySunColor;
        flat out vec3 sunTransmittanceEye;

        #ifdef WORLD_MOON_ENABLED
            flat out vec3 skyMoonColor;
            flat out vec3 moonTransmittanceEye;
        #endif
    #endif
#endif

#ifdef SKY_ENABLED
    uniform sampler3D TEX_SUN_TRANSMIT;

    uniform vec3 skyColor;
    uniform float wetness;
    uniform float eyeAltitude;

    #ifdef SHADOW_ENABLED
        //flat out vec3 skyLightColor;

        uniform vec3 shadowLightPosition;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            uniform mat4 shadowModelView;
            uniform float near;
            uniform float far;

            #if MC_VERSION >= 11700 && !defined IS_IRIS
                uniform vec3 chunkOffset;
            #endif

            #ifndef IS_IRIS
                // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
                uniform mat4 gbufferPreviousModelView;
                uniform mat4 gbufferPreviousProjection;
            #else
                //uniform mat4 gbufferModelView;
                uniform mat4 gbufferProjection;
            #endif
        #endif
    #endif
#endif

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float screenBrightness;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int moonPhase;
uniform int worldTime;

uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifndef IRIS_FEATURE_SSBO
    #include "/lib/camera/exposure.glsl"

    #include "/lib/lighting/blackbody.glsl"

    #ifdef SKY_ENABLED
        #include "/lib/sky/hillaire_common.glsl"
        #include "/lib/celestial/position.glsl"
        #include "/lib/celestial/transmittance.glsl"
        #include "/lib/world/sky.glsl"
    #endif
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #ifndef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();

        blockLightColor = blackbody(BLOCKLIGHT_TEMP);

        #ifdef SKY_ENABLED
            skyLightLevels = GetSkyLightLevels();
            float eyeElevation = GetScaledSkyHeight(eyeAltitude);

            skySunColor = GetSunColor();

            sunTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.x);

            #ifdef WORLD_MOON_ENABLED
                skyMoonColor = GetMoonColor();

                moonTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.y);
            #endif
        #endif
    #endif
}
