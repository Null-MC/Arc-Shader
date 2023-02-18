#define LIGHT_MAX_COUNT 16384
#define LIGHT_REGION_MAX_COUNT 16 // [4 8 12 16 20 24 32 48 64]
#define LIGHT_REGION_SIZE 4.0
#define LIGHT_SIZE_X 32
#define LIGHT_SIZE_Y 16
#define LIGHT_SIZE_Z 32
#define LIGHT_SIZE_XYZ 16384
#define LIGHT_MASK_SIZE 2

const ivec3 SceneLightGridSize = ivec3(LIGHT_SIZE_X, LIGHT_SIZE_Y, LIGHT_SIZE_Z);
const vec3 LightGridCenter = (SceneLightGridSize * LIGHT_REGION_SIZE) / 2.0;


struct SceneLightData {
    vec3 Position;
    vec4 Color;
};

#if defined RENDER_BEGIN || defined RENDER_SHADOW
    layout(std430, binding = 2) buffer globalLightingData
#else
    layout(std430, binding = 2) readonly buffer globalLightingData
#endif
{
    int SceneLightCount;
    SceneLightData SceneLights[];
};

#if defined RENDER_BEGIN || defined RENDER_SHADOW
    layout(std430, binding = 3) buffer localLightingData
#else
    layout(std430, binding = 3) readonly buffer localLightingData
#endif
{
    int[LIGHT_SIZE_XYZ] SceneLightMapCounts; // 65536
    int[LIGHT_SIZE_XYZ][LIGHT_REGION_MAX_COUNT] SceneLightMap; // 1048576
    uint[LIGHT_SIZE_XYZ][LIGHT_MASK_SIZE] SceneLightPositionMask; // 131072
};

// #ifdef RENDER_SHADOW
//     layout(r32ui) uniform uimage2D sceneLightMaps;
// #else
//     layout(r32ui) readonly uniform uimage2D sceneLightMaps;
// #endif

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

    uint maskIndex = (blockPos.z << 4) | (blockPos.y << 2) | blockPos.x;
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
    //imageStore(sceneLightMaps, ivec2(gridIndex, gridLightIndex), uvec4(lightIndex));

    vec3 offsetLightPos = position - fract(cameraPosition) + 0.5;

    SceneLightData light;
    light.Position = offsetLightPos;
    light.Color = color;
    SceneLights[lightIndex] = light;

    #ifdef LIGHT_COLOR_NEIGHBORS
        ivec3 rangeGridPosMin = GetSceneLightGridPosition(offsetLightPos - color.a); // - 0.5
        ivec3 rangeGridPosMax = GetSceneLightGridPosition(offsetLightPos + color.a); // + 0.5
        ivec3 neighborGridPos;

        for (neighborGridPos.z = rangeGridPosMin.z; neighborGridPos.z <= rangeGridPosMax.z; neighborGridPos.z++) {
            for (neighborGridPos.y = rangeGridPosMin.y; neighborGridPos.y <= rangeGridPosMax.y; neighborGridPos.y++) {
                for (neighborGridPos.x = rangeGridPosMin.x; neighborGridPos.x <= rangeGridPosMax.x; neighborGridPos.x++) {
                    if (neighborGridPos == gridPos || any(lessThan(neighborGridPos, ivec3(0.0))) || any(greaterThanEqual(neighborGridPos, SceneLightGridSize))) continue;

                    int neighborGridIndex = GetSceneLightGridIndex(neighborGridPos);
                    int neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1);
                    if (neighborLightIndex < LIGHT_REGION_MAX_COUNT)
                        SceneLightMap[neighborGridIndex][neighborLightIndex] = lightIndex;
                        //imageStore(sceneLightMaps, ivec2(neighborGridIndex, neighborLightIndex), uvec4(lightIndex));
                }
            }
        }
    #endif
}

vec3 GetSceneLighting(const in vec3 position, const in vec3 geoNormal, const in vec3 texNormal) {
    ivec3 gridPos, blockPos;
    if (!GetSceneLightGridPosition(position, gridPos, blockPos)) return vec3(0.0);
    int gridIndex = GetSceneLightGridIndex(gridPos);

    #ifdef LIGHT_DEBUG_MASK
        uint maskIndex = (blockPos.z << 4) | (blockPos.y << 2) | blockPos.x;
        uint intIndex = maskIndex >> 5;
        uint bitIndex = maskIndex & 31;
        uint bit = 1 << bitIndex;
        uint mask = SceneLightPositionMask[gridIndex][intIndex];
        return vec3((mask & bit) != 0 ? 1.0 : 0.0);
    #endif

    vec3 color = vec3(0.0);
    for (int i = 0; i < min(SceneLightMapCounts[gridIndex], LIGHT_REGION_MAX_COUNT); i++) {
        int lightIndex = SceneLightMap[gridIndex][i];
        //int lightIndex = int(imageLoad(sceneLightMaps, ivec2(gridIndex, i)).r);
        SceneLightData light = SceneLights[lightIndex];

        vec3 lightVec = light.Position - position;
        float lightDist = length(lightVec);
        vec3 lightDir = lightVec / max(lightDist, EPSILON);

        //float lightAtt = (light.Color.a * 0.25) / (lightDist*lightDist);
        float lightAtt = saturate((light.Color.a - lightDist) / 15.0);
        //lightAtt = pow(lightAtt, 0.5);
        lightAtt = pow2(lightAtt);
        
        //float brightnessScale = 15.0 / light.Color.a;
        //lightAtt *= brightnessScale;

        float NoLm = max(dot(texNormal, lightDir), 0.0);
        NoLm *= step(0.0, dot(geoNormal, lightDir));
        color += RGBToLinear(light.Color.rgb) * NoLm * lightAtt;
    }

    return color;
}
