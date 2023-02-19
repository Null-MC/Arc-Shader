#define LIGHT_MAX_COUNT 800000
#define LIGHT_REGION_MAX_COUNT 32 // [4 8 12 16 20 24 32 48 64]
#define LIGHT_REGION_SIZE 4.0
#define LIGHT_SIZE_X 48
#define LIGHT_SIZE_Y 32
#define LIGHT_SIZE_Z 48
#define LIGHT_SIZE_XYZ 73728
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
    uint SceneLightCount;
    SceneLightData SceneLights[];
};

#if defined RENDER_BEGIN || defined RENDER_SHADOW
    layout(std430, binding = 3) buffer localLightingData
#else
    layout(std430, binding = 3) readonly buffer localLightingData
#endif
{
    uint[LIGHT_SIZE_XYZ] SceneLightMapCounts; // 524288
    uint[LIGHT_SIZE_XYZ][LIGHT_MASK_SIZE] SceneLightPositionMask; // 1048576
};

#ifdef RENDER_SHADOW
    layout(r32ui) uniform restrict writeonly uimage2D sceneLightMaps;
#else
    layout(r32ui) uniform restrict readonly uimage2D sceneLightMaps;
#endif

vec3 GetLightGridPosition(const in vec3 position) {
    vec3 cameraOffset = fract(cameraPosition / LIGHT_REGION_SIZE) * LIGHT_REGION_SIZE;
    return position + LightGridCenter + cameraOffset;
}

ivec3 GetSceneLightGridCell(const in vec3 gridPos) {
    return ivec3(floor(gridPos / LIGHT_REGION_SIZE + 0.001));
}

bool GetSceneLightGridCell(const in vec3 gridPos, out ivec3 gridCell, out ivec3 blockCell) {
    gridCell = GetSceneLightGridCell(gridPos);
    if (any(lessThan(gridCell, ivec3(0.0))) || any(greaterThanEqual(gridCell, SceneLightGridSize))) return false;

    blockCell = ivec3(floor(gridPos - gridCell * LIGHT_REGION_SIZE));
    return true;
}

uint GetSceneLightGridIndex(const in ivec3 gridCell) {
    return gridCell.z * (LIGHT_SIZE_Y * LIGHT_SIZE_X) + gridCell.y * LIGHT_SIZE_X + gridCell.x;
}

ivec2 GetSceneLightUV(const in uint gridIndex, const in uint gridLightIndex) {
    uint x = gridIndex % 2048;
    uint y = gridIndex / 2048;
    return ivec2(x, y * LIGHT_REGION_MAX_COUNT + gridLightIndex);
}

void AddSceneLight(const in vec3 position, const in vec4 color) {
    ivec3 gridCell, blockCell;
    vec3 gridPos = GetLightGridPosition(position);
    if (!GetSceneLightGridCell(gridPos, gridCell, blockCell)) return;
    uint gridIndex = GetSceneLightGridIndex(gridCell);

    uint maskIndex = (blockCell.z << 4) | (blockCell.y << 2) | blockCell.x;
    uint intIndex = maskIndex >> 5;
    uint bitIndex = maskIndex & 31;
    uint bit = 1 << bitIndex;

    uint status = atomicOr(SceneLightPositionMask[gridIndex][intIndex], bit);
    if ((status & bit) != 0) return;

    uint gridLightIndex = atomicAdd(SceneLightMapCounts[gridIndex], 1u);
    if (gridLightIndex >= LIGHT_REGION_MAX_COUNT) return;

    uint lightIndex = atomicAdd(SceneLightCount, 1u);
    if (lightIndex >= LIGHT_MAX_COUNT) return;

    SceneLights[lightIndex] = SceneLightData(position, color);
    ivec2 uv = GetSceneLightUV(gridIndex, gridLightIndex);
    imageStore(sceneLightMaps, uv, uvec4(lightIndex));

    #ifdef LIGHT_COLOR_NEIGHBORS
        vec3 neighborGridPosMin = GetLightGridPosition(position - color.a);
        ivec3 neighborGridCellMin = GetSceneLightGridCell(neighborGridPosMin);

        vec3 neighborGridPosMax = GetLightGridPosition(position + color.a);
        ivec3 neighborGridCellMax = GetSceneLightGridCell(neighborGridPosMax);

        ivec3 neighborGridCell;
        for (neighborGridCell.z = neighborGridCellMin.z; neighborGridCell.z <= neighborGridCellMax.z; neighborGridCell.z++) {
            for (neighborGridCell.y = neighborGridCellMin.y; neighborGridCell.y <= neighborGridCellMax.y; neighborGridCell.y++) {
                for (neighborGridCell.x = neighborGridCellMin.x; neighborGridCell.x <= neighborGridCellMax.x; neighborGridCell.x++) {
                    if (neighborGridCell == gridCell || any(lessThan(neighborGridCell, ivec3(0.0))) || any(greaterThanEqual(neighborGridCell, SceneLightGridSize))) continue;

                    uint neighborGridIndex = GetSceneLightGridIndex(neighborGridCell);
                    uint neighborLightIndex = atomicAdd(SceneLightMapCounts[neighborGridIndex], 1u);
                    if (neighborLightIndex < LIGHT_REGION_MAX_COUNT) {
                        ivec2 neighborUV = GetSceneLightUV(neighborGridIndex, neighborLightIndex);
                        imageStore(sceneLightMaps, neighborUV, uvec4(lightIndex));
                    }
                }
            }
        }
    #endif
}

vec3 GetSceneLighting(const in vec3 position, const in vec3 geoNormal, const in vec3 texNormal) {
    ivec3 gridCell, blockCell;
    vec3 gridPos = GetLightGridPosition(position + 0.01 * geoNormal);
    if (!GetSceneLightGridCell(gridPos, gridCell, blockCell)) return vec3(0.0);
    uint gridIndex = GetSceneLightGridIndex(gridCell);

    //return gridPos / (LIGHT_REGION_SIZE * SceneLightGridSize);
    //return vec3(SceneLightMapCounts[gridIndex] > 8u ? 1.0 : 0.0);
    //return vec3(gridCell) / SceneLightGridSize;
    //return blockCell / float(LIGHT_REGION_SIZE);

    #ifdef LIGHT_DEBUG_MASK
        uint maskIndex = (blockCell.z << 4) | (blockCell.y << 2) | blockCell.x;
        uint intIndex = maskIndex >> 5;
        uint bitIndex = maskIndex & 31;
        uint bit = 1 << bitIndex;
        uint mask = SceneLightPositionMask[gridIndex][intIndex];
        return vec3((mask & bit) != 0 ? 1.0 : 0.0);
    #endif

    vec3 color = vec3(0.0);
    for (int i = 0; i < min(SceneLightMapCounts[gridIndex], LIGHT_REGION_MAX_COUNT); i++) {
        ivec2 uv = GetSceneLightUV(gridIndex, i);
        uint lightIndex = imageLoad(sceneLightMaps, uv).r;
        SceneLightData light = SceneLights[lightIndex];

        vec3 lightVec = light.Position - position;
        float lightDist = length(lightVec);
        vec3 lightDir = lightVec / max(lightDist, EPSILON);

        //float lightAtt = (light.Color.a * 0.25) / (lightDist*lightDist);
        float lightAtt = saturate((light.Color.a - lightDist) / 15.0);
        //lightAtt = pow(lightAtt, 0.5);
        lightAtt = pow2(lightAtt);
        
        lightAtt *= 15.0 / light.Color.a;

        float NoLm = max(dot(texNormal, lightDir), 0.0);
        NoLm *= step(0.0, dot(geoNormal, lightDir));
        color += RGBToLinear(light.Color.rgb) * NoLm * lightAtt;
    }

    return color;
}
