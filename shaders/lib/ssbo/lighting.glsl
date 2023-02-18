#define LIGHT_MAX_COUNT 200000 // 1048576
#define LIGHT_SIZE_X 64
#define LIGHT_SIZE_Y 32
#define LIGHT_SIZE_Z 64
#define LIGHT_SIZE_XYZ 131072
#define LIGHT_REGION_SIZE 8.0
#define LIGHT_REGION_MAX_COUNT 8

const ivec3 SceneLightGridSize = ivec3(LIGHT_SIZE_X, LIGHT_SIZE_Y, LIGHT_SIZE_Z);
const vec3 LightGridCenter = (SceneLightGridSize * LIGHT_REGION_SIZE) / 2.0;


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

ivec3 GetSceneLightGridPosition(const in vec3 position) {
    vec3 cameraOffset = fract(cameraPosition / LIGHT_REGION_SIZE) * LIGHT_REGION_SIZE;
    return ivec3(floor((position + cameraOffset + LightGridCenter) / LIGHT_REGION_SIZE + 0.001));
}

bool GetSceneLightGridPosition(const in vec3 position, out ivec3 gridPos, out ivec3 blockPos) {
    vec3 cameraOffset = fract(cameraPosition / LIGHT_REGION_SIZE) * LIGHT_REGION_SIZE;
    gridPos = ivec3(floor((position + cameraOffset + LightGridCenter) / LIGHT_REGION_SIZE + 0.001));

    if (any(lessThan(gridPos, ivec3(0.0))) || any(greaterThanEqual(gridPos, SceneLightGridSize))) return false;

    blockPos = ivec3(floor(position + cameraOffset + LightGridCenter - gridPos * LIGHT_REGION_SIZE + 0.001));
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
        ivec3 rangeGridPosMin = GetSceneLightGridPosition(position - color.a);
        ivec3 rangeGridPosMax = GetSceneLightGridPosition(position + color.a);

        for (int z = rangeGridPosMin.z; z <= rangeGridPosMax.z; z++) {
            for (int y = rangeGridPosMin.y; y <= rangeGridPosMax.y; y++) {
                for (int x = rangeGridPosMin.x; x <= rangeGridPosMax.x; x++) {
                    if (x == 0 && y == 0 && z == 0) continue;
                    // TODO: skip if outside max bounds

                    int neighborGridIndex = GetSceneLightGridIndex(ivec3(x, y, z));

                    int neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1);
                    if (neighborLightIndex < LIGHT_REGION_MAX_COUNT)
                        SceneLightMap[neighborGridIndex][neighborLightIndex] = lightIndex;
                }
            }
        }
    #endif
}

vec3 GetSceneLighting(const in vec3 position, const in vec3 normal) {
    ivec3 gridPos, blockPos;
    if (!GetSceneLightGridPosition(position, gridPos, blockPos)) return vec3(0.0);
    int gridIndex = GetSceneLightGridIndex(gridPos);

    uint maskIndex = (blockPos.z << 6) | (blockPos.y << 3) | blockPos.x;
    uint intIndex = maskIndex >> 5;
    uint bitIndex = maskIndex & 31;
    uint bit = 1 << bitIndex;
    uint mask = SceneLightPositionMask[gridIndex][intIndex];
    //return vec3((mask & bit) != 0 ? 1.0 : 0.0);

    vec3 color = vec3(0.0);
    for (int i = 0; i < min(SceneLightMapCounts[gridIndex], LIGHT_REGION_MAX_COUNT); i++) {
        int lightIndex = SceneLightMap[gridIndex][i];
        vec3 lightPosition = SceneLightPosition[lightIndex] - fract(cameraPosition) + 0.5;
        vec4 lightColor = SceneLightColor[lightIndex];

        vec3 lightVec = lightPosition - position;
        float lightDist = length(lightVec);
        vec3 lightDir = lightVec / max(lightDist, EPSILON);

        float NoLm = max(dot(normal, lightDir), 0.0);
        float lightAtt = (lightColor.a * 0.25) / (lightDist*lightDist);
        color += lightColor.rgb * NoLm * lightAtt;
    }

    return color;
}
