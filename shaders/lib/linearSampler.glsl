float SampleLinear(const in sampler2D sampler, const in vec2 traceAtlasCoord, const in vec2 atlasPixelSize, const in int comp) {
    vec2 f = fract(traceAtlasCoord * atlasSize);
    
    #ifdef PARALLAX_USE_TEXELFETCH
        vec4 depthSamples = textureGather(sampler, traceAtlasCoord, comp);
        float x1 = mix(depthSamples[0], depthSamples[1], f.x);
        float x2 = mix(depthSamples[2], depthSamples[3], f.x);
        return mix(x1, x2, f.y);
    #else
        float depthSample1 = texture2D(sampler, traceAtlasCoord                              )[comp];
        float depthSample2 = texture2D(sampler, traceAtlasCoord+vec2(1.0, 0.0)*atlasPixelSize)[comp];
        float depthSample3 = texture2D(sampler, traceAtlasCoord+vec2(0.0, 1.0)*atlasPixelSize)[comp];
        float depthSample4 = texture2D(sampler, traceAtlasCoord+vec2(1.0, 1.0)*atlasPixelSize)[comp];
        float x1 = mix(depthSample1, depthSample2, f.x);
        float x2 = mix(depthSample3, depthSample4, f.x);
        return mix(x1, x2, f.y);
    #endif
}

vec3 SampleLinearRGB(const in sampler2D sampler, const in vec2 traceAtlasCoord, const in vec2 atlasPixelSize) {
    vec2 f = fract(traceAtlasCoord * atlasSize);
    
    #ifdef PARALLAX_USE_TEXELFETCH
        ivec2 t2 = ivec2(traceAtlasCoord * atlasSize);
        vec3 depthSample1 = texelFetch(sampler, t2,                 0).rgb;
        vec3 depthSample2 = texelFetch(sampler, t2+ivec2(1.0, 0.0), 0).rgb;
        vec3 depthSample3 = texelFetch(sampler, t2+ivec2(0.0, 1.0), 0).rgb;
        vec3 depthSample4 = texelFetch(sampler, t2+ivec2(1.0, 1.0), 0).rgb;
        vec3 x1 = mix(depthSample1, depthSample2, f.x);
        vec3 x2 = mix(depthSample3, depthSample4, f.x);
        return mix(x1, x2, f.y);
    #else
        vec3 depthSample1 = texture2D(sampler, traceAtlasCoord                              ).rgb;
        vec3 depthSample2 = texture2D(sampler, traceAtlasCoord+vec2(1.0, 0.0)*atlasPixelSize).rgb;
        vec3 depthSample3 = texture2D(sampler, traceAtlasCoord+vec2(0.0, 1.0)*atlasPixelSize).rgb;
        vec3 depthSample4 = texture2D(sampler, traceAtlasCoord+vec2(1.0, 1.0)*atlasPixelSize).rgb;
        vec3 x1 = mix(depthSample1, depthSample2, f.x);
        vec3 x2 = mix(depthSample3, depthSample4, f.x);
        return mix(x1, x2, f.y);
    #endif
}
