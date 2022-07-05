int GetBloomTileCount() {
    int lodCount = textureQueryLevels(colortex4);
    return clamp(lodCount, 1, 12);
}

float GetBloomTilePos(const in int tile) {
    return 1.0 - (1.0 / exp2(tile));
}

float GetBloomTileSize(const in int tile) {
    float tileMin = GetBloomTilePos(tile);
    float tileMax = GetBloomTilePos(tile + 1);
    return tileMax - tileMin;
}

void GetBloomTileOuterBounds(const in int tile, out vec2 boundsMin, out vec2 boundsMax) {
    float fx = floor(tile * 0.5) * 2.0;
    float fy = fract(tile * 0.5) * 2.0;

    vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
    boundsMin.x = (2.0 / 3.0) * (1.0 - exp2(-fx) + fx * pixelSize.x) + fx * pixelSize.x;
    boundsMin.y = fy * (0.5 + 4.0 * pixelSize.y);

    float tileSize = GetBloomTileSize(tile);
    boundsMax = boundsMin + tileSize + 2.0 * pixelSize;
}

void GetBloomTileInnerBounds(const in int tile, out vec2 boundsMin, out vec2 boundsMax) {
    GetBloomTileOuterBounds(tile, boundsMin, boundsMax);

    vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
    vec2 center = 0.5 * (boundsMin + boundsMax);
    boundsMin = min(boundsMin + pixelSize, center);
    boundsMax = max(boundsMax - pixelSize, center);
}

int GetBloomTileInnerIndex(const in int tileCount, out vec2 tileMin, out vec2 tileMax) {
    vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

    for (int i = 0; i < tileCount; i++) {
        GetBloomTileInnerBounds(i, tileMin, tileMax);

        if (texcoord.x > tileMin.x && texcoord.x <= tileMax.x
         && texcoord.y > tileMin.y && texcoord.y <= tileMax.y) return i;
    }

    return -1;
}

#ifdef RENDER_COMPOSITE_BLOOM_BLUR
    const float BloomOffsets[3] = float[](
        1.411764705882353, 3.2941176470588234, 5.176470588235294);

    const float BloomWeights[7] = float[](
        0.1964825501511404, 0.2969069646728344, 0.2969069646728344, 0.09447039785044732,
        0.09447039785044732, 0.010381362401148057, 0.010381362401148057);

    vec3 BloomBlur13(const in vec2 uv, const in vec2 tileMin, const in vec2 tileMax, const in vec2 direction) {
        vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
        vec3 color = vec3(0.0);

        vec2 off1 = vec2(BloomOffsets[0]) * direction;
        vec2 off2 = vec2(BloomOffsets[1]) * direction;
        vec2 off3 = vec2(BloomOffsets[2]) * direction;

        color += texture2DLod(colortex7, uv, 0).rgb * BloomWeights[0];

        vec2 uv1 = min(uv + off1 * pixelSize, tileMax);
        color += texture2DLod(colortex7, uv1, 0).rgb * BloomWeights[1];

        vec2 uv2 = max(uv - off1 * pixelSize, tileMin);
        color += texture2DLod(colortex7, uv2, 0).rgb * BloomWeights[2];

        vec2 uv3 = min(uv + off2 * pixelSize, tileMax);
        color += texture2DLod(colortex7, uv3, 0).rgb * BloomWeights[3];

        vec2 uv4 = max(uv - off2 * pixelSize, tileMin);
        color += texture2DLod(colortex7, uv4, 0).rgb * BloomWeights[4];

        vec2 uv5 = min(uv + off3 * pixelSize, tileMax);
        color += texture2DLod(colortex7, uv5, 0).rgb * BloomWeights[5];

        vec2 uv6 = max(uv - off3 * pixelSize, tileMin);
        color += texture2DLod(colortex7, uv6, 0).rgb * BloomWeights[6];

        return color;
    }
#endif
