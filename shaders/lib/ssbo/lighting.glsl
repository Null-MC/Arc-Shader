#define LIGHT_MAX_COUNT 4200000000u
#define LIGHT_MASK_SIZE (LIGHT_BIN_SIZE*LIGHT_BIN_SIZE*LIGHT_BIN_SIZE/32)
#define LIGHT_COLOR_NEIGHBORS
//#define LIGHT_DEBUG_MASK

const ivec3 SceneLightGridSize = ivec3(LIGHT_SIZE_XZ, LIGHT_SIZE_Y, LIGHT_SIZE_XZ);
const ivec3 SceneLightSize = SceneLightGridSize * LIGHT_BIN_SIZE;
const vec3 LightGridCenter = (SceneLightGridSize * LIGHT_BIN_SIZE) / 2.0;
const int lightMaskBitCount = int(log2(LIGHT_BIN_SIZE));


struct SceneLightData {
    vec3 position;
    float range;
    vec4 color;
};

struct LightCellData {
    uint LightCount;
    uint[LIGHT_MASK_SIZE] Mask;
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
    LightCellData[] SceneLightMaps;
};

#ifdef RENDER_SHADOW
    layout(r32ui) uniform restrict writeonly uimage2D imgSceneLights;
#else
    layout(r32ui) uniform restrict readonly uimage2D imgSceneLights;
#endif

vec3 GetLightGridPosition(const in vec3 position) {
    vec3 cameraOffset = fract(cameraPosition / LIGHT_BIN_SIZE) * LIGHT_BIN_SIZE;
    return position + LightGridCenter + cameraOffset;
}

ivec3 GetSceneLightGridCell(const in vec3 gridPos) {
    return ivec3(floor(gridPos / LIGHT_BIN_SIZE + 0.001));
}

bool GetSceneLightGridCell(const in vec3 gridPos, out ivec3 gridCell, out ivec3 blockCell) {
    gridCell = GetSceneLightGridCell(gridPos);
    if (any(lessThan(gridCell, ivec3(0.0))) || any(greaterThanEqual(gridCell, SceneLightGridSize))) return false;

    blockCell = ivec3(floor(gridPos - gridCell * LIGHT_BIN_SIZE));
    return true;
}

uint GetSceneLightGridIndex(const in ivec3 gridCell) {
    return gridCell.z * (LIGHT_SIZE_Y * LIGHT_SIZE_XZ) + gridCell.y * LIGHT_SIZE_XZ + gridCell.x;
}

ivec2 GetSceneLightUV(const in uint gridIndex, const in uint gridLightIndex) {
    uint y = uint(gridIndex / 4096) * LIGHT_BIN_MAX_COUNT;
    return ivec2(gridIndex % 4096, y + gridLightIndex);
}

#if defined RENDER_SHADOW
    void AddSceneLight(const in vec3 position, const in float range, const in vec4 color) {
        ivec3 gridCell, blockCell;
        vec3 gridPos = GetLightGridPosition(position);
        if (!GetSceneLightGridCell(gridPos, gridCell, blockCell)) return;
        uint gridIndex = GetSceneLightGridIndex(gridCell);

        uint maskIndex = (blockCell.z << (lightMaskBitCount * 2)) | (blockCell.y << lightMaskBitCount) | blockCell.x;
        uint intIndex = maskIndex >> 5;
        uint bitIndex = maskIndex & 31;
        uint bit = 1 << bitIndex;

        uint status = atomicOr(SceneLightMaps[gridIndex].Mask[intIndex], bit);
        if ((status & bit) != 0) return;

        uint gridLightIndex = atomicAdd(SceneLightMaps[gridIndex].LightCount, 1u);
        if (gridLightIndex >= LIGHT_BIN_MAX_COUNT) return;

        uint lightIndex = atomicAdd(SceneLightCount, 1u);
        if (lightIndex >= LIGHT_MAX_COUNT) return;

        SceneLights[lightIndex] = SceneLightData(position, range, color);
        ivec2 uv = GetSceneLightUV(gridIndex, gridLightIndex);
        imageStore(imgSceneLights, uv, uvec4(lightIndex));

        #ifdef LIGHT_COLOR_NEIGHBORS
            vec3 neighborGridPosMin = GetLightGridPosition(position - range);
            ivec3 neighborGridCellMin = GetSceneLightGridCell(neighborGridPosMin);

            vec3 neighborGridPosMax = GetLightGridPosition(position + range);
            ivec3 neighborGridCellMax = GetSceneLightGridCell(neighborGridPosMax);

            ivec3 neighborGridCell;
            for (neighborGridCell.z = neighborGridCellMin.z; neighborGridCell.z <= neighborGridCellMax.z; neighborGridCell.z++) {
                for (neighborGridCell.y = neighborGridCellMin.y; neighborGridCell.y <= neighborGridCellMax.y; neighborGridCell.y++) {
                    for (neighborGridCell.x = neighborGridCellMin.x; neighborGridCell.x <= neighborGridCellMax.x; neighborGridCell.x++) {
                        if (neighborGridCell == gridCell || any(lessThan(neighborGridCell, ivec3(0.0))) || any(greaterThanEqual(neighborGridCell, SceneLightGridSize))) continue;

                        uint neighborGridIndex = GetSceneLightGridIndex(neighborGridCell);
                        uint neighborLightIndex = atomicAdd(SceneLightMaps[neighborGridIndex].LightCount, 1u);
                        if (neighborLightIndex < LIGHT_BIN_MAX_COUNT) {
                            ivec2 neighborUV = GetSceneLightUV(neighborGridIndex, neighborLightIndex);
                            imageStore(imgSceneLights, neighborUV, uvec4(lightIndex));
                        }
                    }
                }
            }
        #endif
    }
#elif !defined RENDER_BEGIN
    vec3 GetSceneLighting(const in vec3 position, const in vec3 geoNormal, const in vec3 texNormal, const in float blockLight) {
        ivec3 gridCell, blockCell;
        vec3 gridPos = GetLightGridPosition(position + 0.01 * geoNormal);

        #ifdef LIGHT_FALLBACK
            // TODO: Add padding/interpolation?
            if (!GetSceneLightGridCell(gridPos, gridCell, blockCell))
                return pow4(blockLight) * blockLightColor;
        #else
            if (!GetSceneLightGridCell(gridPos, gridCell, blockCell))
                return vec3(0.0);
        #endif

        uint gridIndex = GetSceneLightGridIndex(gridCell);

        //return gridPos / (LIGHT_BIN_SIZE * SceneLightGridSize);
        //return vec3(SceneLightMapCounts[gridIndex] > 8u ? 1.0 : 0.0);
        //return vec3(gridCell) / SceneLightGridSize;
        //return blockCell / float(LIGHT_BIN_SIZE);

        #ifdef LIGHT_DEBUG_MASK
            uint maskIndex = (blockCell.z << (lightMaskBitCount * 2)) | (blockCell.y << lightMaskBitCount) | blockCell.x;
            uint intIndex = maskIndex >> 5;
            uint bitIndex = maskIndex & 31;
            uint bit = 1 << bitIndex;
            uint mask = SceneLightMaps[gridIndex].Mask[intIndex];
            return vec3((mask & bit) != 0 ? 1.0 : 0.0);
        #endif

        bool hasGeoNormal = any(greaterThan(abs(geoNormal), EPSILON3));
        bool hasTexNormal = any(greaterThan(abs(texNormal), EPSILON3));

        vec3 color = vec3(0.0);
        for (int i = 0; i < min(SceneLightMaps[gridIndex].LightCount, LIGHT_BIN_MAX_COUNT); i++) {
            ivec2 uv = GetSceneLightUV(gridIndex, i);
            uint lightIndex = imageLoad(imgSceneLights, uv).r;
            SceneLightData light = SceneLights[lightIndex];

            vec3 lightVec = light.position - position;
            float lightDist = length(lightVec);
            vec3 lightDir = lightVec / max(lightDist, EPSILON);
            lightDist = max(lightDist - 0.5, 0.0);

            //float lightAtt = (light.color.a * 0.25) / (lightDist*lightDist);
            float lightAtt = 1.0 - saturate(lightDist / light.range);
            //lightAtt = pow(lightAtt, 0.5);
            lightAtt = pow5(lightAtt);
            
            // if (light.range > EPSILON)
            //     lightAtt *= saturate(15.0 / min(light.range, 15.0));

            float NoLm = 1.0;

            if (hasTexNormal) {
                NoLm *= max(dot(texNormal, lightDir), 0.0);

                if (hasGeoNormal)
                    NoLm *= step(0.0, dot(geoNormal, lightDir));
            }

            color += light.color.rgb * NoLm * lightAtt;
        }

        color *= blockLight;

        #ifdef LIGHT_FALLBACK
            vec3 offsetPos = position + LightGridCenter;
            float fade = minOf(min(offsetPos, SceneLightSize - offsetPos)) / 15.0;
            color = mix(pow4(blockLight) * blockLightColor, color, saturate(fade));
        #endif

        return color;
    }
#endif
