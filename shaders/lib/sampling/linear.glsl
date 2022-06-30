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

float FetchLinear(const in sampler2D sampler, const in vec2 texcoordFull, const in int comp) {
    vec2 f = fract(texcoordFull);
    
    vec4 depthSamples = textureGather(sampler, texcoordFull, comp);
    float x1 = mix(depthSamples[0], depthSamples[1], f.x);
    float x2 = mix(depthSamples[2], depthSamples[3], f.x);
    return mix(x1, x2, f.y);
}

vec3 SampleLinearRGB(const in sampler2D sampler, const in vec2 texcoord, const in vec2 texSize) {
    vec2 f = fract(texcoord * texSize);
    vec2 pixelSize = 1.0 / texSize;
    
    vec3 depthSample1 = texture2DLod(sampler, texcoord                         , 0).rgb;
    vec3 depthSample2 = texture2DLod(sampler, texcoord+vec2(1.0, 0.0)*pixelSize, 0).rgb;
    vec3 depthSample3 = texture2DLod(sampler, texcoord+vec2(0.0, 1.0)*pixelSize, 0).rgb;
    vec3 depthSample4 = texture2DLod(sampler, texcoord+vec2(1.0, 1.0)*pixelSize, 0).rgb;
    vec3 x1 = mix(depthSample1, depthSample2, f.x);
    vec3 x2 = mix(depthSample3, depthSample4, f.x);
    return mix(x1, x2, f.y);
}

vec3 FetchLinearRGB(const in sampler2D sampler, const in vec2 texcoordFull) {
    vec2 f = fract(texcoordFull);
    
    ivec2 itexcoord = ivec2(texcoordFull);
    vec3 depthSample1 = texelFetch(sampler, itexcoord,                 0).rgb;
    vec3 depthSample2 = texelFetch(sampler, itexcoord+ivec2(1.0, 0.0), 0).rgb;
    vec3 depthSample3 = texelFetch(sampler, itexcoord+ivec2(0.0, 1.0), 0).rgb;
    vec3 depthSample4 = texelFetch(sampler, itexcoord+ivec2(1.0, 1.0), 0).rgb;
    vec3 x1 = mix(depthSample1, depthSample2, f.x);
    vec3 x2 = mix(depthSample3, depthSample4, f.x);
    return mix(x1, x2, f.y);
}
