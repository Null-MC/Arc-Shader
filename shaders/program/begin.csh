//#define RENDER_BEGIN_CSM
#define RENDER_BEGIN
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(4, 1, 1);

#if defined IRIS_FEATURE_SSBO && defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
    layout(std430, binding = 0) buffer csmData {
        float cascadeSize[4];           // 16
        vec2 shadowProjectionSize[4];   // 32
        vec2 shadowProjectionPos[4];    // 32
        mat4 cascadeProjection[4];      // 256
    };

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferProjection;
    uniform mat4 shadowModelView;
    uniform float near;
    uniform float far;

    #include "/lib/shadows/csm.glsl"
#endif


void main() {
    #if defined IRIS_FEATURE_SSBO && defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
        float cascadeSizes[4];
        cascadeSizes[0] = GetCascadeDistance(0);
        cascadeSizes[1] = GetCascadeDistance(1);
        cascadeSizes[2] = GetCascadeDistance(2);
        cascadeSizes[3] = GetCascadeDistance(3);

        int i = int(gl_GlobalInvocationID.x);

        cascadeSize[i] = cascadeSizes[i];
        shadowProjectionPos[i] = GetShadowCascadeClipPos(i);
        cascadeProjection[i] = GetShadowCascadeProjectionMatrix(cascadeSizes, i);

        shadowProjectionSize[i] = 2.0 / vec2(
            cascadeProjection[i][0].x,
            cascadeProjection[i][1].y);
    #endif

    barrier();
}
