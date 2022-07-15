// localCoord: local texture coordinate [0-1]
// atlasBounds: [0]=position [1]=size
vec2 GetAtlasCoord(const in vec2 localCoord) {
    return fract(localCoord) * atlasBounds[1] + atlasBounds[0];
}

vec2 GetLocalCoord(const in vec2 atlasCoord) {
    return (atlasCoord - atlasBounds[0]) / max(atlasBounds[1], EPSILON);
}

vec2 GetParallaxCoord(const in mat2 dFdXY, const in vec3 tanViewDir, const in float viewDist, out float texDepth, out vec3 traceDepth) {
    vec2 stepCoord = tanViewDir.xy * PARALLAX_DEPTH / (1.0 + tanViewDir.z * PARALLAX_SAMPLES);
    float stepDepth = 1.0 / PARALLAX_SAMPLES;

    #ifdef PARALLAX_SMOOTH
        vec2 atlasPixelSize = 1.0 / atlasSize;
        float prevTexDepth;
    #endif

    float viewDistF = 1.0 - clamp(viewDist / PARALLAX_DISTANCE, 0.0, 1.0);
    int maxSampleCount = int(viewDistF * PARALLAX_SAMPLES);

    int i;
    texDepth = 1.0;
    float depthDist = 1.0;
    for (i = 0; i <= maxSampleCount && depthDist >= (1.0/255.0); i++) {
        #ifdef PARALLAX_SMOOTH
            prevTexDepth = texDepth;
        #endif

        vec2 localTraceCoord = localCoord - i * stepCoord;

        #ifdef PARALLAX_SMOOTH
            //vec2 traceAtlasCoord = GetAtlasCoord(localCoord - i * stepCoord);
            //texDepth = TextureGradLinear(normals, traceAtlasCoord, atlasSize, dFdXY, 3);

            vec2 uv[4];
            vec2 atlasTileSize = atlasBounds[1] * atlasSize;
            vec2 f = GetLinearCoords(localTraceCoord, atlasTileSize, uv);

            uv[0] = GetAtlasCoord(uv[0]);
            uv[1] = GetAtlasCoord(uv[1]);
            uv[2] = GetAtlasCoord(uv[2]);
            uv[3] = GetAtlasCoord(uv[3]);

            texDepth = TextureGradLinear(normals, uv, dFdXY, f, 3);
        #else
            vec2 traceAtlasCoord = GetAtlasCoord(localTraceCoord);
            //texDepth = textureGrad(normals, traceAtlasCoord, dFdXY[0], dFdXY[1]).a;
            texDepth = texture(normals, traceAtlasCoord).a;
        #endif

        depthDist = 1.0 - i * stepDepth - texDepth;
        //if (texDepth >= 1.0 - i * stepDepth) break;
    }

    i = max(i - 1, 0);
    int pI = max(i - 1, 0);
    //traceDepth.xy = localCoord - pI * stepCoord;
    //traceDepth.z = 1.0 - pI * stepDepth;

    #ifdef PARALLAX_SMOOTH
        vec2 currentTraceOffset = localCoord - i * stepCoord;
        float currentTraceDepth = 1.0 - i * stepDepth;
        vec2 prevTraceOffset = localCoord - pI * stepCoord;
        float prevTraceDepth = 1.0 - pI * stepDepth;

        float t = (prevTraceDepth - prevTexDepth) / max(texDepth - prevTexDepth + prevTraceDepth - currentTraceDepth, EPSILON);
        t = clamp(t, 0.0, 1.0);

        traceDepth.xy = mix(prevTraceOffset, currentTraceOffset, t);
        traceDepth.z = mix(prevTraceDepth, currentTraceDepth, t);
    #else
        // shadow_tex.xy = prevTraceOffset;
        // shadow_tex.z = prevTraceDepth;
        traceDepth.xy = localCoord - pI * stepCoord;
        traceDepth.z = 1.0 - pI * stepDepth;
    #endif

    //return GetAtlasCoord(localCoord - i * stepCoord);
    #ifdef PARALLAX_SMOOTH
        //return i == 1 ? texcoord : GetAtlasCoord(traceDepth.xy);
        return GetAtlasCoord(traceDepth.xy);
    #else
        return GetAtlasCoord(localCoord - i * stepCoord);
    #endif
}

float GetParallaxShadow(const in vec3 traceTex, const in mat2 dFdXY, const in vec3 tanLightDir) {
    vec2 stepCoord = tanLightDir.xy * PARALLAX_DEPTH * (1.0 / (1.0 + tanLightDir.z * PARALLAX_SHADOW_SAMPLES));
    float stepDepth = 1.0 / PARALLAX_SHADOW_SAMPLES;

    float skip = floor(traceTex.z * PARALLAX_SHADOW_SAMPLES + 0.5) / PARALLAX_SHADOW_SAMPLES;

    #ifdef PARALLAX_SMOOTH
        vec2 atlasPixelSize = 1.0 / atlasSize;
    #endif

    int i;
    float shadow = 1.0;
    for (i = 1; i + skip < PARALLAX_SHADOW_SAMPLES && shadow > 0.001; i++) {
        float traceDepth = traceTex.z + i * stepDepth;
        vec2 localCoord = traceTex.xy + i * stepCoord;

        #ifdef PARALLAX_SMOOTH
            //float texDepth = TextureGradLinear(normals, atlasCoord, atlasPixelSize, dFdXY, 3);

            vec2 uv[4];
            vec2 atlasTileSize = atlasBounds[1] * atlasSize;
            vec2 f = GetLinearCoords(localCoord, atlasTileSize, uv);

            uv[0] = GetAtlasCoord(uv[0]);
            uv[1] = GetAtlasCoord(uv[1]);
            uv[2] = GetAtlasCoord(uv[2]);
            uv[3] = GetAtlasCoord(uv[3]);

            float texDepth = TextureGradLinear(normals, uv, dFdXY, f, 3);
        #else
            vec2 atlasCoord = GetAtlasCoord(localCoord);
            float texDepth = textureGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).a;
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
    vec3 GetParallaxSlopeNormal(const in vec2 atlasCoord, const in mat2 dFdXY, const in float traceDepth, const in vec3 tanViewDir) {
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
            float height_x = textureGrad(normals, tX, dFdXY[0], dFdXY[1]).a;
            float height_y = textureGrad(normals, tY, dFdXY[0], dFdXY[1]).a;
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
