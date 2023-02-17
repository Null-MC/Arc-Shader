#define LIGHT_MAX_COUNT 16384 // 1048576
#define LIGHT_SIZE_X 32
#define LIGHT_SIZE_Y 16
#define LIGHT_SIZE_Z 32
#define LIGHT_SIZE_XYZ 16384
#define LIGHT_REGION_SIZE 8.0
#define LIGHT_REGION_MAX_COUNT 8

const ivec3 SceneLightGridSize = ivec3(LIGHT_SIZE_X, LIGHT_SIZE_Y, LIGHT_SIZE_Z);


#if defined RENDER_BEGIN || defined RENDER_SHADOW
    layout(std430, binding = 2) buffer lightingData
#else
    layout(std430, binding = 2) readonly buffer lightingData
#endif
{
    int SceneLightCount;                        // 4
    vec3 SceneLightPosition[LIGHT_MAX_COUNT];   // 16*N = 1024
    vec4 SceneLightColor[LIGHT_MAX_COUNT];      // 16*N = 1024

    int[LIGHT_SIZE_XYZ] SceneLightMapCounts;                      // SIZE * 4 = 65536
    int[LIGHT_SIZE_XYZ][LIGHT_REGION_MAX_COUNT] SceneLightMap;    // SIZE * 32 = 524288
    uint[LIGHT_SIZE_XYZ][16] SceneLightPositionMask;              // SIZE * 64 = 8388608
};

bool GetSceneLightGridPosition(const in vec3 position, out ivec3 gridPos, out ivec3 blockPos) {
    const vec3 gridCenter = (SceneLightGridSize * LIGHT_REGION_SIZE) / 2.0;

    vec3 cameraOffset = fract(cameraPosition / LIGHT_REGION_SIZE) * LIGHT_REGION_SIZE;
    gridPos = ivec3(floor((position + cameraOffset + gridCenter) / LIGHT_REGION_SIZE + 0.001));

    if (any(lessThan(gridPos, ivec3(0.0))) || any(greaterThanEqual(gridPos, SceneLightGridSize))) {
        // blockPos = ivec3(0);
        // blockPos = ivec3(0);
        return false;
    }

    blockPos = ivec3(floor(position + cameraOffset + gridCenter - gridPos * LIGHT_REGION_SIZE + 0.001));
    return true;
}

int GetSceneLightGridIndex(const in ivec3 gridPos) {
    return gridPos.z * (LIGHT_SIZE_Y * LIGHT_SIZE_X) + gridPos.y * LIGHT_SIZE_X + gridPos.x;
}

void AddSceneLight(const in vec3 position, const in vec4 color) {
    ivec3 gridPos, blockPos;
    if (!GetSceneLightGridPosition(position, gridPos, blockPos)) return;
    int gridIndex = GetSceneLightGridIndex(gridPos);

    uint maskIndex = (blockPos.z << 6) | (blockPos.y << 3) | blockPos.x;
    uint intIndex = maskIndex >> 5;
    uint bitIndex = maskIndex & 31;
    uint bit = 1 << bitIndex;

    //uint maskData = 1 << bitIndex;
    uint status = atomicOr(SceneLightPositionMask[gridIndex][intIndex], bit);
    if ((status & bit) != 0) return;

    int gridLightIndex = atomicAdd(SceneLightMapCounts[gridIndex], 1);
    if (gridLightIndex >= LIGHT_REGION_MAX_COUNT) return;

    int lightIndex = atomicAdd(SceneLightCount, 1);
    if (lightIndex >= LIGHT_MAX_COUNT) return;

    SceneLightMap[gridIndex][gridLightIndex] = lightIndex;
    SceneLightPosition[lightIndex] = position;
    SceneLightColor[lightIndex] = color;

    #ifdef LIGHT_COLOR_NEIGHBORS
        // Add to neighbor cells if they intersect light range
        ivec3 neighborMin = max(gridPos - 1, ivec3(0));
        ivec3 neighborMax = min(gridPos + 1, SceneLightGridSize - 1);

        for (int z = neighborMin.z; z <= neighborMax.z; z++) {
            if (color.a > blockPos.x) {
                // TODO: Add to -X
                int neighborGridIndex = gridIndex - 1 + z * (LIGHT_SIZE_Y * LIGHT_SIZE_X);
                int neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1);
                if (neighborLightIndex < LIGHT_REGION_MAX_COUNT)
                    SceneLightMap[neighborGridIndex][neighborLightIndex] = lightIndex;
            }
            if (blockPos.x + color.a > LIGHT_REGION_SIZE) {
                // TODO: Add to +X
                int neighborGridIndex = gridIndex + 1 + z * (LIGHT_SIZE_Y * LIGHT_SIZE_X);
                int neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1);
                if (neighborLightIndex < LIGHT_REGION_MAX_COUNT)
                    SceneLightMap[neighborGridIndex][neighborLightIndex] = lightIndex;
            }
        }

        for (int x = neighborMin.x; x <= neighborMax.x; x++) {
            if (color.a > blockPos.z) {
                // TODO: Add to -Z
                int neighborGridIndex = gridIndex - (LIGHT_SIZE_Y * LIGHT_SIZE_X) + x;
                int neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1);
                if (neighborLightIndex < LIGHT_REGION_MAX_COUNT)
                    SceneLightMap[neighborGridIndex][neighborLightIndex] = lightIndex;
            }
            if (blockPos.z + color.a > LIGHT_REGION_SIZE) {
                // TODO: Add to +Z
                int neighborGridIndex = gridIndex + (LIGHT_SIZE_Y * LIGHT_SIZE_X) + x;
                int neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1);
                if (neighborLightIndex < LIGHT_REGION_MAX_COUNT)
                    SceneLightMap[neighborGridIndex][neighborLightIndex] = lightIndex;
            }
        }

        // for (int z = neighborMin.z; z <= neighborMax.z; z++) {
        //     for (int y = neighborMin.y; y <= neighborMax.y; y++) {
        //         for (int x = neighborMin.x; x <= neighborMax.x; x++) {
        //             if (x == 0 && y == 0 && z == 0) continue;

        //             int neighborGridIndex = gridIndex
        //                 + z * (LIGHT_SIZE_Y * LIGHT_SIZE_X)
        //                 + y * LIGHT_SIZE_X
        //                 + x;

        //             int neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1);
        //             if (neighborLightIndex < LIGHT_REGION_MAX_COUNT)
        //                 SceneLightMap[neighborGridIndex][neighborLightIndex] = lightIndex;
        //         }
        //     }
        // }
    #endif
}

vec3 GetSceneLighting(const in vec3 position) {
    ivec3 gridPos, blockPos;
    if (!GetSceneLightGridPosition(position, gridPos, blockPos)) return vec3(0.0);
    int gridIndex = GetSceneLightGridIndex(gridPos);
    //return vec3(gridIndex > 0 ? 1.0 : 0.0);
    //return vec3(SceneLightCount > 8 ? 1.0 : 0.0);

    int gridLightCount = SceneLightMapCounts[gridIndex];
    //return vec3(gridLightCount > 8 ? 1.0 : 0.0);

    uint maskIndex = (blockPos.z << 6) | (blockPos.y << 3) | blockPos.x;
    uint intIndex = maskIndex >> 5;
    uint bitIndex = maskIndex & 31;
    uint bit = 1 << bitIndex;
    uint mask = SceneLightPositionMask[gridIndex][intIndex];
    //return vec3((mask & bit) != 0 ? 1.0 : 0.0);


    vec3 color = vec3(0.0);
    for (int i = 0; i < min(SceneLightMapCounts[gridIndex], LIGHT_REGION_MAX_COUNT); i++) {
        int lightIndex = SceneLightMap[gridIndex][i];
        //if (lightIndex)
        vec3 lightPosition = SceneLightPosition[lightIndex] - fract(cameraPosition) + 0.5;
        vec4 lightColor = SceneLightColor[lightIndex];

        float lightAtt = saturate(lightColor.a - length(position - lightPosition));
        color += lightColor.rgb * lightAtt;
    }

    return color;
}
