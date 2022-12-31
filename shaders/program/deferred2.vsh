#define RENDER_VERTEX
#define RENDER_DEFERRED
#define RENDER_RSM

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out float exposure;

uniform float screenBrightness;
uniform float viewWidth;
uniform float viewHeight;

uniform float nightVision;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out float cascadeSizes[4];
    flat out vec3 matShadowProjections_scale[4];
    flat out vec3 matShadowProjections_translation[4];
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
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
        uniform mat4 gbufferModelView;
        uniform mat4 gbufferProjection;
    #endif

    #include "/lib/shadows/csm.glsl"
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform int heldBlockLightValue;
    
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
#endif

#include "/lib/camera/exposure.glsl"


void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    exposure = GetExposure();

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
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
}
