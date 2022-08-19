#ifndef MC_GL_ARB_texture_query_levels
    int textureQueryLevels(sampler2D samplerName) {
        ivec2 size = textureSize(samplerName, 0);
        return log2(size) + 1;
    }
#endif
