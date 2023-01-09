#define RENDER_VERTEX
#define RENDER_DEFERRED
#define RENDER_OPAQUE_FINAL

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
        uniform sampler3D colortex0;
    #endif

    uniform vec3 skyColor;
    uniform float wetness;
    uniform float eyeAltitude;

    #ifdef SHADOW_ENABLED
        //flat out vec3 skyLightColor;

        uniform vec3 shadowLightPosition;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            flat out float cascadeSizes[4];
            flat out vec3 matShadowProjections_scale[4];
            flat out vec3 matShadowProjections_translation[4];

            uniform mat4 shadowModelView;
            uniform float near;
            uniform float far;

            #if MC_VERSION >= 11700 && (SHADER_PLATFORM != PLATFORM_IRIS || defined IRIS_FEATURE_CHUNK_OFFSET)
                uniform vec3 chunkOffset;
            #else
                uniform mat4 gbufferModelViewInverse;
            #endif

            #if SHADER_PLATFORM == PLATFORM_OPTIFINE
                // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
                uniform mat4 gbufferPreviousModelView;
                uniform mat4 gbufferPreviousProjection;
            #else
                //uniform mat4 gbufferModelView;
                uniform mat4 gbufferProjection;
            #endif

            #include "/lib/shadows/csm.glsl"
        #endif
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
            sunTransmittanceEye = GetSunTransmittance(colortex0, eyeAltitude, skyLightLevels.x);
            moonTransmittanceEye = GetMoonTransmittance(colortex0, eyeAltitude, skyLightLevels.y);
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
            cascadeSizes[0] = GetCascadeDistance(0);
            cascadeSizes[1] = GetCascadeDistance(1);
            cascadeSizes[2] = GetCascadeDistance(2);
            cascadeSizes[3] = GetCascadeDistance(3);

            mat4 matShadowProjection0 = GetShadowCascadeProjectionMatrix(cascadeSizes, 0);
            mat4 matShadowProjection1 = GetShadowCascadeProjectionMatrix(cascadeSizes, 1);
            mat4 matShadowProjection2 = GetShadowCascadeProjectionMatrix(cascadeSizes, 2);
            mat4 matShadowProjection3 = GetShadowCascadeProjectionMatrix(cascadeSizes, 3);

            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection0, matShadowProjections_scale[0], matShadowProjections_translation[0]);
            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection1, matShadowProjections_scale[1], matShadowProjections_translation[1]);
            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection2, matShadowProjections_scale[2], matShadowProjections_translation[2]);
            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection3, matShadowProjections_scale[3], matShadowProjections_translation[3]);
        #endif
    #endif

    blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

    exposure = GetExposure();
}
