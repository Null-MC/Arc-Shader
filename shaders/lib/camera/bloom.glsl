//#ifdef RENDER_VERTEX
    int GetBloomTileCount() {
        //#if BLOOM_LOD_MAX > 0
        //    const int lodMax = BLOOM_LOD_MAX;
        //#else
        //    const int lodMax = 99;
        //#endif

        //int lodCount = textureQueryLevels(BUFFER_HDR);
        //return clamp(lodCount - 2, 1, lodMax);
        
        vec2 viewSize = vec2(viewWidth, viewHeight);
        return int(ceil(minOf(log2(viewSize)))) - 1;
    }
//#endif

#ifdef RENDER_FRAG
    float GetBloomTilePos(const in int tile) {
        return 1.0 - rcp(exp2(tile));
    }

    float GetBloomTileSize(const in int tile) {
        float tileMin = GetBloomTilePos(tile);
        float tileMax = GetBloomTilePos(tile + 1);
        return tileMax - tileMin;
    }

    void GetBloomTileOuterBounds(const in int tile, out vec2 boundsMin, out vec2 boundsMax) {
        float fx = floor(tile * 0.5) * 2.0;
        float fy = fract(tile * 0.5) * 2.0;

        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec2 pixelSize = rcp(viewSize);

        boundsMin.x = (2.0 / 3.0) * (1.0 - exp2(-fx) + fx * pixelSize.x) + fx * pixelSize.x;
        boundsMin.y = fy * (0.5 + 4.0 * pixelSize.y);

        float tileSize = GetBloomTileSize(tile);
        boundsMax = boundsMin + tileSize + 2.0 * pixelSize;
    }

    void GetBloomTileInnerBounds(const in int tile, out vec2 boundsMin, out vec2 boundsMax) {
        GetBloomTileOuterBounds(tile, boundsMin, boundsMax);

        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec2 pixelSize = rcp(viewSize);
        vec2 center = 0.5 * (boundsMin + boundsMax);
        boundsMin = min(boundsMin + pixelSize, center);
        boundsMax = max(boundsMax - pixelSize, center);
    }

    int GetBloomTileInnerIndex(const in int tileCount, out vec2 tileMin, out vec2 tileMax) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec2 pixelSize = rcp(viewSize);

        for (int i = 0; i < tileCount; i++) {
            GetBloomTileInnerBounds(i, tileMin, tileMax);
            if (clamp(texcoord, tileMin, tileMax) == texcoord) return i;
        }

        return -1;
    }
#endif
