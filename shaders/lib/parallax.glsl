// localCoord: local texture coordinate [0-1]
// atlasBounds: [0]=position [1]=size
vec2 GetAtlasCoord(const in vec2 localCoord) {
    return fract(localCoord) * atlasBounds[1] + atlasBounds[0];
}

vec2 GetLocalCoord(const in vec2 atlasCoord) {
    return (atlasCoord - atlasBounds[0]) / atlasBounds[1];
}

#ifdef PARALLAX_USE_TEXELFETCH
    vec2 GetParallaxCoord(const in vec3 tanViewDir, out float texDepth, out vec3 traceDepth) {
#else
    vec2 GetParallaxCoord(const in mat2 dFdXY, const in vec3 tanViewDir, out float texDepth, out vec3 traceDepth) {
#endif
    vec2 stepCoord = tanViewDir.xy * PARALLAX_DEPTH / (1.0 + tanViewDir.z * PARALLAX_SAMPLES);
    float stepDepth = 1.0 / PARALLAX_SAMPLES;

    int i;
    //int sampleCount = PARALLAX_SAMPLES;
    texDepth = 1.0;
    for (i = 0; i <= PARALLAX_SAMPLES; i++) {
        vec2 traceAtlasCoord = GetAtlasCoord(localCoord - i * stepCoord);

        #ifdef PARALLAX_USE_TEXELFETCH
            texDepth = texelFetch(normals, ivec2(traceAtlasCoord * atlasSize), 0).a;
        #else
            texDepth = texture2DGrad(normals, traceAtlasCoord, dFdXY[0], dFdXY[1]).a;
        #endif

        if (texDepth >= 1.0 - i * stepDepth) break;
        //sampleCount *= int(step(texDepth, 1.0 - i * stepDepth));
    }

    //i -= 1;

    int pI = max(i - 1, 0);
    traceDepth.xy = localCoord - pI * stepCoord;
    traceDepth.z = 1.0 - pI * stepDepth;

    //return GetAtlasCoord(localCoord - i * stepCoord);
    return i == 0 ? texcoord : GetAtlasCoord(localCoord - i * stepCoord);
}

#ifdef PARALLAX_USE_TEXELFETCH
    float GetParallaxShadow(const in vec3 traceTex, const in vec3 tanLightDir) {
#else
    float GetParallaxShadow(const in vec3 traceTex, const in mat2 dFdXY, const in vec3 tanLightDir) {
#endif
    vec2 stepCoord = tanLightDir.xy * PARALLAX_DEPTH * (1.0 / (1.0 + tanLightDir.z * PARALLAX_SHADOW_SAMPLES));
    float stepDepth = 1.0 / PARALLAX_SHADOW_SAMPLES;

    float skip = floor(traceTex.z * PARALLAX_SHADOW_SAMPLES + 0.5) / PARALLAX_SHADOW_SAMPLES;

    int i;
    float shadow = 1.0;
    for (i = 1; i + skip < PARALLAX_SHADOW_SAMPLES && shadow > 0.001; i++) {
        float traceDepth = traceTex.z + i * stepDepth;
        vec2 atlasCoord = GetAtlasCoord(traceTex.xy + i * stepCoord);

        #ifdef PARALLAX_USE_TEXELFETCH
            float texDepth = texelFetch(normals, ivec2(atlasCoord * atlasSize), 0).a;
        #else
            float texDepth = texture2DGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).a;
        #endif

        #ifdef PARALLAX_SOFTSHADOW
            float depthF = max(texDepth - traceDepth, 0.0) / stepDepth;
            shadow -= PARALLAX_SOFTSHADOW_FACTOR * depthF * stepDepth;
        #else
            shadow *= step(texDepth + EPSILON, traceDepth);
        #endif
    }

    return max(shadow, 0.0);
}

#ifdef PARALLAX_SLOPE_NORMALS
    #ifdef PARALLAX_USE_TEXELFETCH
        vec3 GetParallaxSlopeNormal(const in vec2 atlasCoord, const in float traceDepth, const in vec3 tanViewDir) {
    #else
        vec3 GetParallaxSlopeNormal(const in vec2 atlasCoord, const in mat2 dFdXY, const in float traceDepth, const in vec3 tanViewDir) {
    #endif
        vec2 atlasPixelSize = 1.0 / atlasSize;
        float atlasAspect = atlasSize.x / atlasSize.y;

        vec2 tex_snapped = floor(atlasCoord * atlasSize) * atlasPixelSize;
        vec2 tex_offset = atlasCoord - (tex_snapped + 0.5 * atlasPixelSize);

        vec2 stepSign = sign(tex_offset);
        vec2 viewSign = sign(tanViewDir.xy);

        bool dir = abs(tex_offset.x  * atlasAspect) < abs(tex_offset.y);
        vec2 tex_x, tex_y;

        if (dir) {
            tex_x = vec2(-viewSign.x, 0.0);
            tex_y = vec2(0.0, stepSign.y);
        }
        else {
            tex_x = vec2(stepSign.x, 0.0);
            tex_y = vec2(0.0, -viewSign.y);
        }

        vec2 tX = GetLocalCoord(atlasCoord + tex_x * atlasPixelSize);
        tX = GetAtlasCoord(tX);

        vec2 tY = GetLocalCoord(atlasCoord + tex_y * atlasPixelSize);
        tY = GetAtlasCoord(tY);

        #ifdef PARALLAX_USE_TEXELFETCH
            float height_x = texelFetch(normals, ivec2(tX * atlasSize), 0).a;
            float height_y = texelFetch(normals, ivec2(tY * atlasSize), 0).a;
        #else
            float height_x = texture2DGrad(normals, tX, dFdXY[0], dFdXY[1]).a;
            float height_y = texture2DGrad(normals, tY, dFdXY[0], dFdXY[1]).a;
        #endif

        if (dir) {
            if (!(traceDepth > height_y && viewSign.y != stepSign.y)) {
                if (traceDepth > height_x) return vec3(-viewSign.x, 0.0, 0.0);

                if (abs(tanViewDir.y) > abs(tanViewDir.x))
                    return vec3(0.0, -viewSign.y, 0.0);
                else
                    return vec3(-viewSign.x, 0.0, 0.0);
            }

            return vec3(0.0, -viewSign.y, 0.0);
        }
        else {
            if (!(traceDepth > height_x && viewSign.x != stepSign.x)) {
                if (traceDepth > height_y) return vec3(0.0, -viewSign.y, 0.0);

                if (abs(tanViewDir.y) > abs(tanViewDir.x))
                    return vec3(0.0, -viewSign.y, 0.0);
                else
                    return vec3(-viewSign.x, 0.0, 0.0);
            }

            return vec3(-viewSign.x, 0.0, 0.0);
        }
    }
#endif
