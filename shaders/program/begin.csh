#define RENDER_BEGIN
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef IRIS_FEATURE_SSBO
    layout(std430, binding = 0) buffer csmData {
        float sceneExposure;            // 4
        mat4 shadowModelViewEx;         // 64
        mat4 shadowProjectionEx;        // 64

        // CSM
        float cascadeSize[4];           // 16
        vec2 shadowProjectionSize[4];   // 32
        vec2 shadowProjectionPos[4];    // 32
        mat4 cascadeProjection[4];      // 256
    };

    uniform float viewWidth;
    uniform float viewHeight;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    uniform float nightVision;

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        uniform mat4 gbufferModelView;
        uniform mat4 shadowModelView;
        uniform vec3 cameraPosition;
        uniform int worldTime;
        uniform float far;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            //uniform mat4 gbufferModelView;
            uniform mat4 gbufferPreviousModelView;
            uniform mat4 gbufferPreviousProjection;
            uniform mat4 gbufferProjection;
            uniform float near;
        #endif

        #include "/lib/matrix.glsl"
        #include "/lib/celestial/position.glsl"
        #include "/lib/shadows/common.glsl"

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
        #endif
    #endif

    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    #ifdef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            shadowModelViewEx = BuildShadowViewMatrix();

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                cascadeSize[0] = GetCascadeDistance(0);
                cascadeSize[1] = GetCascadeDistance(1);
                cascadeSize[2] = GetCascadeDistance(2);
                cascadeSize[3] = GetCascadeDistance(3);

                for (int i = 0; i < 4; i++) {
                    shadowProjectionPos[i] = GetShadowCascadeClipPos(i);
                    cascadeProjection[i] = GetShadowCascadeProjectionMatrix(cascadeSize, i);

                    shadowProjectionSize[i] = 2.0 / vec2(
                        cascadeProjection[i][0].x,
                        cascadeProjection[i][1].y);
                }
            #else
                shadowProjectionEx = BuildShadowProjectionMatrix();
            #endif
        #endif
    #endif

    barrier();
}
