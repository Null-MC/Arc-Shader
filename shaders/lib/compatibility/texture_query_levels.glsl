#ifndef MC_GL_ARB_texture_query_levels
    int textureQueryLevels(sampler2D samplerName) {
        ivec2 texSize = textureSize(samplerName, 0);
        int size = min(texSize.x, texSize.y);
        return int(log2(size) + 1);
    }
#endif
