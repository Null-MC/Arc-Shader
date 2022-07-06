float SampleLinear(const in sampler2D sampler, const in vec2 texcoord, const in vec2 texSize, const in int comp) {
    vec2 f = fract(texcoord * texSize);
    vec2 pixelSize = 1.0 / texSize;
    
    float depthSample1 = texture2DLod(sampler, texcoord                         , 0)[comp];
    float depthSample2 = texture2DLod(sampler, texcoord+vec2(1.0, 0.0)*pixelSize, 0)[comp];
    float depthSample3 = texture2DLod(sampler, texcoord+vec2(0.0, 1.0)*pixelSize, 0)[comp];
    float depthSample4 = texture2DLod(sampler, texcoord+vec2(1.0, 1.0)*pixelSize, 0)[comp];
    float x1 = mix(depthSample1, depthSample2, f.x);
    float x2 = mix(depthSample3, depthSample4, f.x);
    return mix(x1, x2, f.y);
}

float FetchLinear(const in sampler2D samplerName, const in vec2 texcoordFull, const in int comp) {
    vec2 f = fract(texcoordFull);
    
    vec4 depthSamples = textureGather(samplerName, texcoordFull, comp);
    float x1 = mix(depthSamples[0], depthSamples[1], f.x);
    float x2 = mix(depthSamples[2], depthSamples[3], f.x);
    return mix(x1, x2, f.y);
}

vec3 TextureLodLinearRGB(const in sampler2D samplerName, const in vec2 texcoord, const in vec2 texSize, const in int lod) {
    vec2 f = fract(texcoord * texSize);
    vec2 pixelSize = 1.0 / texSize;
    
    vec3 depthSample1 = texture2DLod(samplerName, texcoord                         , lod).rgb;
    vec3 depthSample2 = texture2DLod(samplerName, texcoord+vec2(1.0, 0.0)*pixelSize, lod).rgb;
    vec3 depthSample3 = texture2DLod(samplerName, texcoord+vec2(0.0, 1.0)*pixelSize, lod).rgb;
    vec3 depthSample4 = texture2DLod(samplerName, texcoord+vec2(1.0, 1.0)*pixelSize, lod).rgb;
    vec3 x1 = mix(depthSample1, depthSample2, f.x);
    vec3 x2 = mix(depthSample3, depthSample4, f.x);
    return mix(x1, x2, f.y);
}

vec3 TextureGradLinearRGB(const in sampler2D samplerName, const in vec2 texcoord, const in vec2 texSize, const in mat2 dFdXY) {
    vec2 f = fract(texcoord * texSize);
    vec2 pixelSize = 1.0 / texSize;
    
    vec3 depthSample1 = texture2DGrad(samplerName, texcoord                         , dFdXY[0], dFdXY[1]).rgb;
    vec3 depthSample2 = texture2DGrad(samplerName, texcoord+vec2(1.0, 0.0)*pixelSize, dFdXY[0], dFdXY[1]).rgb;
    vec3 depthSample3 = texture2DGrad(samplerName, texcoord+vec2(0.0, 1.0)*pixelSize, dFdXY[0], dFdXY[1]).rgb;
    vec3 depthSample4 = texture2DGrad(samplerName, texcoord+vec2(1.0, 1.0)*pixelSize, dFdXY[0], dFdXY[1]).rgb;
    vec3 x1 = mix(depthSample1, depthSample2, f.x);
    vec3 x2 = mix(depthSample3, depthSample4, f.x);
    return mix(x1, x2, f.y);
}

vec3 TexelFetchLinearRGB(const in sampler2D samplerName, const in vec2 texcoordFull) {
    vec2 f = fract(texcoordFull);
    
    ivec2 itexcoord = ivec2(texcoordFull);
    vec3 depthSample1 = texelFetch(samplerName, itexcoord,                 0).rgb;
    vec3 depthSample2 = texelFetch(samplerName, itexcoord+ivec2(1.0, 0.0), 0).rgb;
    vec3 depthSample3 = texelFetch(samplerName, itexcoord+ivec2(0.0, 1.0), 0).rgb;
    vec3 depthSample4 = texelFetch(samplerName, itexcoord+ivec2(1.0, 1.0), 0).rgb;
    vec3 x1 = mix(depthSample1, depthSample2, f.x);
    vec3 x2 = mix(depthSample3, depthSample4, f.x);
    return mix(x1, x2, f.y);
}
