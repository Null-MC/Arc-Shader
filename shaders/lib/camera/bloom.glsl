#ifdef RENDER_VERTEX
    int GetBloomTileCount(const in vec2 screenSize) {
        return int(ceil(minOf(0.5 * log2(0.5*screenSize)))) - 1;
    }
#endif

#ifdef RENDER_FRAG
    float GetBloomTilePos(const in int tile) {
        return 1.0 - rcp(exp2(float(tile)));
    }

    float GetBloomTileSize(const in int tile) {
        float tileMin = GetBloomTilePos(tile);
        float tileMax = GetBloomTilePos(tile + 1);
        return tileMax - tileMin;
    }

    void GetBloomTileOuterBounds(const in vec2 screenSize, const in int tile, out vec2 boundsMin, out vec2 boundsMax) {
        float tileSize = GetBloomTileSize(tile * 2);
        
        float tileF = float(tile);
        float fx = fract(tileF * 0.5) * 2.0;
        float fy = floor(tileF * 0.5) * 2.0;

        vec2 pixelSize = rcp(screenSize);
        boundsMin.x = fx * (0.75 - 2.0 * pixelSize.x);
        boundsMin.y = 0.75 * (1.0 - exp2(-fy) + fy * pixelSize.y) + fy * pixelSize.y;

        boundsMax = boundsMin + tileSize + 2.0 * pixelSize;
    }

    void GetBloomTileInnerBounds(const in vec2 screenSize, const in int tile, out vec2 boundsMin, out vec2 boundsMax) {
        GetBloomTileOuterBounds(screenSize, tile, boundsMin, boundsMax);

        vec2 pixelSize = rcp(screenSize);
        vec2 center = 0.5 * (boundsMin + boundsMax);
        
        boundsMin = min(boundsMin + pixelSize, center);
        boundsMax = max(boundsMax - pixelSize, center);
    }

    int GetBloomTileInnerIndex(const in vec2 screenSize, const in int tileCount, out vec2 tileMin, out vec2 tileMax) {
        vec2 pixelSize = rcp(vec2(viewWidth, viewHeight));
        int tileIndex = -1;

        for (int i = 0; i < tileCount && tileIndex < 0; i++) {
            GetBloomTileInnerBounds(screenSize, i, tileMin, tileMax);
            if (clamp(texcoord, tileMin, tileMax) == texcoord) tileIndex = i;
        }

        return tileIndex;
    }

    #ifdef RENDER_COMPOSITE_BLOOM_BLUR
        vec3 BloomBlur13(const in vec2 uv, const in vec2 tileMin, const in vec2 tileMax, const in vec2 direction) {
            vec2 pixelSize = rcp(0.5 * vec2(viewWidth, viewHeight));

            vec2 off1 = 1.411764705882353 * direction * pixelSize;
            vec2 off2 = 3.2941176470588234 * direction * pixelSize;
            vec2 off3 = 5.176470588235294 * direction * pixelSize;

            vec3 color = textureLod(BUFFER_BLOOM, uv, 0).rgb * 0.1964825501511404;

            vec2 uv1 = uv + off1;
            if (uv1.x < tileMax.x && uv1.y < tileMax.y)
                color += textureLod(BUFFER_BLOOM, uv1, 0).rgb * 0.2969069646728344;

            vec2 uv2 = uv - off1;
            if (uv2.x > tileMin.x && uv2.y > tileMin.y)
                color += textureLod(BUFFER_BLOOM, uv2, 0).rgb * 0.2969069646728344;

            vec2 uv3 = uv + off2;
            if (uv3.x < tileMax.x && uv3.y < tileMax.y)
                color += textureLod(BUFFER_BLOOM, uv3, 0).rgb * 0.09447039785044732;

            vec2 uv4 = uv - off2;
            if (uv4.x > tileMin.x && uv4.y > tileMin.y)
                color += textureLod(BUFFER_BLOOM, uv4, 0).rgb * 0.09447039785044732;

            vec2 uv5 = uv + off3;
            if (uv5.x < tileMax.x && uv5.y < tileMax.y)
                color += textureLod(BUFFER_BLOOM, uv5, 0).rgb * 0.010381362401148057;

            vec2 uv6 = uv - off3;
            if (uv6.x > tileMin.x && uv6.y > tileMin.y)
                color += textureLod(BUFFER_BLOOM, uv6, 0).rgb * 0.010381362401148057;

            return color;
        }
    #endif
#endif
