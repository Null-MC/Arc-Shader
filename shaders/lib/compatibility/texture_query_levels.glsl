int textureQueryLevels(sampler2D samplerName) {
    ivec2 size = textureSize(samplerName, 0);
    return log2(size) + 1;
}
