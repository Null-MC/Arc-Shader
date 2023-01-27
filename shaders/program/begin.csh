#define RENDER_BEGIN
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef IRIS_FEATURE_SSBO
    layout(std430, binding = 0) buffer csmData {
        mat4 shadowModelViewEx;         // 64

        // CSM
        float cascadeSize[4];           // 16
        vec2 shadowProjectionSize[4];   // 32
        vec2 shadowProjectionPos[4];    // 32
        mat4 cascadeProjection[4];      // 256
    };

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        uniform mat4 gbufferModelView;
        uniform mat4 shadowModelView;
        uniform vec3 cameraPosition;
        uniform int worldTime;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            //uniform mat4 gbufferModelView;
            uniform mat4 gbufferProjection;
            uniform float near;
            uniform float far;
        #endif

        #include "/lib/matrix.glsl"
        #include "/lib/celestial/position.glsl"
        #include "/lib/shadows/common.glsl"

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
        #endif
    #endif
#endif


void main() {
    #ifdef IRIS_FEATURE_SSBO
        // Sky stuff

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
            #endif
        #endif
    #endif

    barrier();
}
