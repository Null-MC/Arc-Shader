//#define RENDER_BEGIN_CSM
#define RENDER_BEGIN
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(4, 1, 1);

// layout(shared, binding = 0) buffer layoutName {
//     float cascadeSize[4];
//     mat4 cascadedShadowProjection[4];
// };

#if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
        uniform mat4 gbufferModelView;
        uniform mat4 gbufferProjection;
        uniform mat4 shadowModelView;
        uniform float near;
        uniform float far;

        #include "/lib/shadows/csm.glsl"
    #endif
#endif


void main() {
    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
        float cascadeSizes[4];
        cascadeSizes[0] = GetCascadeDistance(0);
        cascadeSizes[1] = GetCascadeDistance(1);
        cascadeSizes[2] = GetCascadeDistance(2);
        cascadeSizes[3] = GetCascadeDistance(3);

        int i = int(gl_GlobalInvocationID.x);
        cascadeSize[i] = cascadeSizes[i];
        cascadedShadowProjection[i] = GetShadowCascadeProjectionMatrix(cascadeSizes, i);
    #endif

    barrier();
}
