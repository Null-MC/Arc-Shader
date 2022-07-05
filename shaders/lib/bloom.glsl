//const int BloomTileCount = 6;

const float BloomSampleWeight[7] = float[] (
    0.030078323, 0.104983664, 0.222250419, 0.285375187, 0.222250419, 0.104983664, 0.030078323);


float GetBloomTilePos(const in int tile) {
    //vec2 padding = 16.0 / vec2(viewWidth, viewHeight);
    return 1.0 - (1.0 / exp2(tile)); // + tile*padding;
}

float GetBloomTileMin(const in int tile) {
    return GetBloomTilePos(tile);
}

float GetBloomTileMax(const in int tile) {
    return GetBloomTilePos(tile + 1);
}

int GetBloomTileIndex(const in int tileCount, out float tileMin, out float tileMax) {
    for (int i = 0; i < tileCount; i++) {
        tileMin = GetBloomTileMin(i);
        tileMax = GetBloomTileMax(i);

        if (texcoord.x >= tileMin && texcoord.x < tileMax
         && texcoord.y >= tileMin && texcoord.y < tileMax) return i;
    }

    return -1;
}

#ifdef RENDER_COMPOSITE_BLOOM_BLUR
    vec3 BloomBlur13(const in vec2 uv, const in vec2 resolution, const in vec2 direction) {
      vec3 color = vec3(0.0);
      vec2 off1 = vec2(1.411764705882353) * direction;
      vec2 off2 = vec2(3.2941176470588234) * direction;
      vec2 off3 = vec2(5.176470588235294) * direction;
      color += texture2D(colortex7, uv).rgb * 0.1964825501511404;
      color += texture2D(colortex7, uv + (off1 / resolution)).rgb * 0.2969069646728344;
      color += texture2D(colortex7, uv - (off1 / resolution)).rgb * 0.2969069646728344;
      color += texture2D(colortex7, uv + (off2 / resolution)).rgb * 0.09447039785044732;
      color += texture2D(colortex7, uv - (off2 / resolution)).rgb * 0.09447039785044732;
      color += texture2D(colortex7, uv + (off3 / resolution)).rgb * 0.010381362401148057;
      color += texture2D(colortex7, uv - (off3 / resolution)).rgb * 0.010381362401148057;
      return color;
    }
#endif
