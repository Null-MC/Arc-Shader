vec2 GetLinearCoords(const in vec2 texcoord, const in vec2 texSize, out vec2 uv[4]) {
    vec2 f = fract(texcoord * texSize);
    vec2 pixelSize = 1.0 / texSize;

    uv[0] = texcoord - f*pixelSize;
    uv[1] = uv[0] + vec2(1.0, 0.0)*pixelSize;
    uv[2] = uv[0] + vec2(0.0, 1.0)*pixelSize;
    uv[3] = uv[0] + vec2(1.0, 1.0)*pixelSize;

    return f;
}

vec2 GetLinearCoords(const in vec2 texcoordFull, out ivec2 uv[4]) {
    vec2 f = fract(texcoordFull);

    ivec2 iuv[4];
    iuv[0] = ivec2(texcoordFull - f);
    iuv[1] = iuv[0]+ivec2(1, 0);
    iuv[2] = iuv[0]+ivec2(0, 1);
    iuv[3] = iuv[0]+ivec2(1, 1);

    return f;
}

float LinearBlend4(const in vec4 samples, const in vec2 f) {
    float x1 = mix(samples[0], samples[1], f.x);
    float x2 = mix(samples[2], samples[3], f.x);
    return mix(x1, x2, f.y);
}

vec3 LinearBlend4(const in vec3 samples[4], const in vec2 f) {
    vec3 x1 = mix(samples[0], samples[1], f.x);
    vec3 x2 = mix(samples[2], samples[3], f.x);
    return mix(x1, x2, f.y);
}

float TextureLodLinear(const in sampler2D samplerName, const in vec2 uv[4], const in float lod, const in vec2 f, const in int comp) {
    vec4 samples;
    samples[0] = texture2DLod(samplerName, uv[0], lod)[comp];
    samples[1] = texture2DLod(samplerName, uv[1], lod)[comp];
    samples[2] = texture2DLod(samplerName, uv[2], lod)[comp];
    samples[3] = texture2DLod(samplerName, uv[3], lod)[comp];
    return LinearBlend4(samples, f);
}

float TextureLodLinear(const in sampler2D samplerName, const in vec2 texcoord, const in vec2 texSize, const in int lod, const in int comp) {
    vec2 uv[4];
    vec2 f = GetLinearCoords(texcoord, texSize, uv);
    return TextureLodLinear(samplerName, uv, lod, f, comp);
}

float TextureGradLinear(const in sampler2D samplerName, const in vec2 uv[4], const in mat2 dFdXY, const in vec2 f, const in int comp) {
    vec4 samples;
    samples[0] = texture2DGrad(samplerName, uv[0], dFdXY[0], dFdXY[1])[comp];
    samples[1] = texture2DGrad(samplerName, uv[1], dFdXY[0], dFdXY[1])[comp];
    samples[2] = texture2DGrad(samplerName, uv[2], dFdXY[0], dFdXY[1])[comp];
    samples[3] = texture2DGrad(samplerName, uv[3], dFdXY[0], dFdXY[1])[comp];
    return LinearBlend4(samples, f);
}

float TextureGradLinear(const in sampler2D samplerName, const in vec2 texcoord, const in vec2 texSize, const in mat2 dFdXY, const in int comp) {
    vec2 uv[4];
    vec2 f = GetLinearCoords(texcoord, texSize, uv);
    return TextureGradLinear(samplerName, uv, dFdXY, f, comp);
}

// float TexelGatherLinear(const in sampler2D samplerName, const in vec2 texcoordFull, const in int comp) {
//     vec2 f = fract(texcoordFull);
//     vec4 samples = textureGather(samplerName, texcoordFull, comp);
//     return LinearBlend4(samples, f);
// }

vec3 TextureLodLinearRGB(const in sampler2D samplerName, const in vec2 uv[4], const in int lod, const in vec2 f) {
    vec3 samples[4];
    samples[0] = texture2DLod(samplerName, uv[0], lod).rgb;
    samples[1] = texture2DLod(samplerName, uv[1], lod).rgb;
    samples[2] = texture2DLod(samplerName, uv[2], lod).rgb;
    samples[3] = texture2DLod(samplerName, uv[3], lod).rgb;
    return LinearBlend4(samples, f);
}

vec3 TextureLodLinearRGB(const in sampler2D samplerName, const in vec2 texcoord, const in vec2 texSize, const in int lod) {
    vec2 uv[4];
    vec2 f = GetLinearCoords(texcoord, texSize, uv);
    return TextureLodLinearRGB(samplerName, uv, lod, f);
}

vec3 TextureGradLinearRGB(const in sampler2D samplerName, const in vec2 uv[4], const in mat2 dFdXY, const in vec2 f) {
    vec3 samples[4];
    samples[0] = texture2DGrad(samplerName, uv[0], dFdXY[0], dFdXY[1]).rgb;
    samples[1] = texture2DGrad(samplerName, uv[1], dFdXY[0], dFdXY[1]).rgb;
    samples[2] = texture2DGrad(samplerName, uv[2], dFdXY[0], dFdXY[1]).rgb;
    samples[3] = texture2DGrad(samplerName, uv[3], dFdXY[0], dFdXY[1]).rgb;
    return LinearBlend4(samples, f);
}

vec3 TextureGradLinearRGB(const in sampler2D samplerName, const in vec2 texcoord, const in vec2 texSize, const in mat2 dFdXY) {
    vec2 uv[4];
    vec2 f = GetLinearCoords(texcoord, texSize, uv);
    return TextureGradLinearRGB(samplerName, uv, dFdXY, f);
}

vec3 TexelFetchLinearRGB(const in sampler2D samplerName, const in ivec2 iuv[4], const in int lod, const in vec2 f) {
    vec3 samples[4];
    samples[0] = texelFetch(samplerName, iuv[0], lod).rgb;
    samples[1] = texelFetch(samplerName, iuv[1], lod).rgb;
    samples[2] = texelFetch(samplerName, iuv[2], lod).rgb;
    samples[3] = texelFetch(samplerName, iuv[3], lod).rgb;
    return LinearBlend4(samples, f);
}

vec3 TexelFetchLinearRGB(const in sampler2D samplerName, const in vec2 texcoordFull, const in int lod) {
    ivec2 iuv[4];
    vec2 f = GetLinearCoords(texcoordFull, iuv);
    return TexelFetchLinearRGB(samplerName, iuv, lod, f);
}
