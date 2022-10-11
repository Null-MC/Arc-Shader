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
    flat out vec2 skyLightLevels;
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec3 sunTransmittanceEye;

    uniform sampler2D colortex7;

    uniform vec3 skyColor;
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

            #if MC_VERSION >= 11700 && (defined IS_OPTIFINE || defined IRIS_FEATURE_CHUNK_OFFSET)
                uniform vec3 chunkOffset;
            #else
                uniform mat4 gbufferModelViewInverse;
            #endif

            #ifdef IS_OPTIFINE
                // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
                uniform mat4 gbufferPreviousModelView;
                uniform mat4 gbufferPreviousProjection;
            #else
                uniform mat4 gbufferModelView;
                uniform mat4 gbufferProjection;
            #endif

            #include "/lib/shadows/csm.glsl"
        #endif
    #endif
#endif

uniform float screenBrightness;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform float blindness;

uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int moonPhase;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/world/sun.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #ifdef SKY_ENABLED
        skyLightLevels = GetSkyLightLevels();
        //vec3 sunTransmittance = GetSunTransmittance(colortex7, skyLightLevels.x);

        //sunColor = sunTransmittance * GetSunLux();

        vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
        //sunColor = GetSunLightLuxColor(skyLightTemps.x, skyLightLevels.x);
        moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);

        sunColor = blackbody(5500.0);

        sunTransmittanceEye = GetSunTransmittance(colortex7, eyeAltitude, skyLightLevels.x);// * sunColor;

        //skyLightColor = GetSkyLightLuxColor(skyLightLevels);
        //skyLightColor = sunColor + moonColor; // TODO: get rid of this variable

        // TODO: add lightning check
        // if (rainStrength > 0.5) {
        //     // if (all(greaterThan(skyColor, vec3(0.9)))) {
        //     //     skyLightColor = vec3(60000.0, 0.0, 0.0);
        //     // }
        //     if (dot(shadowLightPosition, shadowLightPosition) < 0.1) {
        //         skyLightColor = vec3(60000.0, 0.0, 0.0);
        //         skyLightLevels = vec2(1.0, 1.0);
        //     }
        // }

        #if defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
            cascadeSizes[0] = GetCascadeDistance(0);
            cascadeSizes[1] = GetCascadeDistance(1);
            cascadeSizes[2] = GetCascadeDistance(2);
            cascadeSizes[3] = GetCascadeDistance(3);

            GetShadowCascadeProjectionMatrix_AsParts(0, matShadowProjections_scale[0], matShadowProjections_translation[0]);
            GetShadowCascadeProjectionMatrix_AsParts(1, matShadowProjections_scale[1], matShadowProjections_translation[1]);
            GetShadowCascadeProjectionMatrix_AsParts(2, matShadowProjections_scale[2], matShadowProjections_translation[2]);
            GetShadowCascadeProjectionMatrix_AsParts(3, matShadowProjections_scale[3], matShadowProjections_translation[3]);
        #endif
    #endif

    blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

    exposure = GetExposure();
}
