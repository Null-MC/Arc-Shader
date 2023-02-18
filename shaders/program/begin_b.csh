#define RENDER_BEGIN_LIGHTING
#define RENDER_BEGIN
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

const ivec3 workGroups = ivec3(8, 4, 8);

#ifdef IRIS_FEATURE_SSBO
    uniform vec3 cameraPosition;

    #include "/lib/ssbo/lighting.glsl"
#endif


void main() {
    #ifdef IRIS_FEATURE_SSBO
        ivec3 pos = ivec3(gl_GlobalInvocationID);
        int gridIndex = pos.z * (LIGHT_SIZE_Y * LIGHT_SIZE_X) + pos.y * LIGHT_SIZE_X + pos.x;

        SceneLightMapCounts[gridIndex] = 0;

        for (int i = 0; i < LIGHT_MASK_SIZE; i++)
            SceneLightPositionMask[gridIndex][i] = 0u;
    #endif

    barrier();
}
