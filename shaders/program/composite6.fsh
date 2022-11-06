#define RENDER_FRAG
#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_BLOOM_DOWNSCALE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
flat in int tileCount;
flat in float exposure;

uniform sampler2D BUFFER_HDR;
uniform sampler2D BUFFER_LUMINANCE;
uniform sampler2D depthtex0;

uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;

#include "/lib/camera/bloom.glsl"

/* RENDERTARGETS: 7 */
out vec3 outColor0;


int GetBloomTileOuterIndex(const in int tileCount) {
    vec2 tileMin, tileMax;
    for (int i = 0; i < tileCount; i++) {
        GetBloomTileOuterBounds(i, tileMin, tileMax);

        if (texcoord.x > tileMin.x && texcoord.x <= tileMax.x
         && texcoord.y > tileMin.y && texcoord.y <= tileMax.y) return i;
    }

    return -1;
}

void ChangeLuminance(inout vec3 color, const in float lumNew) {
    float lumPrev = luminance(color);
    color *= (lumNew / max(lumPrev, EPSILON));
}

void main() {
    int tile = GetBloomTileOuterIndex(tileCount);
    vec3 final = vec3(0.0);

    if (tile >= 0) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec2 pixelSize = rcp(viewSize);

        vec2 tileMin, tileMax;
        GetBloomTileInnerBounds(tile, tileMin, tileMax);

        vec2 tileSize = tileMax - tileMin;
        vec2 tileTex = (texcoord - tileMin) / tileSize;
        int t = tile + 1;//max(tile - 1, 0);

        #ifdef BLOOM_SMOOTH
            vec2 tilePixelSize = pixelSize * exp2(t);

            vec2 uv1 = tileTex + vec2(-0.25, -0.25) * tilePixelSize;
            vec2 uv2 = tileTex + vec2( 0.75, -0.25) * tilePixelSize;
            vec2 uv3 = tileTex + vec2(-0.25,  0.75) * tilePixelSize;
            vec2 uv4 = tileTex + vec2( 0.75,  0.75) * tilePixelSize;

            vec3 sample1 = textureLod(BUFFER_HDR, uv1, t).rgb;
            vec3 sample2 = textureLod(BUFFER_HDR, uv2, t).rgb;
            vec3 sample3 = textureLod(BUFFER_HDR, uv3, t).rgb;
            vec3 sample4 = textureLod(BUFFER_HDR, uv4, t).rgb;
            
            final = 0.25 * (sample1 + sample2 + sample3 + sample4);

            vec4 lumSample;// = textureGather(BUFFER_LUMINANCE, tileTex, 0);
            lumSample[0] = textureLod(BUFFER_LUMINANCE, uv1, t).r;
            lumSample[1] = textureLod(BUFFER_LUMINANCE, uv2, t).r;
            lumSample[2] = textureLod(BUFFER_LUMINANCE, uv3, t).r;
            lumSample[3] = textureLod(BUFFER_LUMINANCE, uv4, t).r;
            float lum = (lumSample[0] + lumSample[1] + lumSample[2] + lumSample[3]) * 0.25;
            // float lum = 0.25 * (
            //     max(exp2(lumSample[0]) - EPSILON, 0.0) +
            //     max(exp2(lumSample[1]) - EPSILON, 0.0) +
            //     max(exp2(lumSample[2]) - EPSILON, 0.0) +
            //     max(exp2(lumSample[3]) - EPSILON, 0.0));
        #else
            //ivec2 iuv = ivec2(tileTex * viewSize / exp2(t));
            final = textureLod(BUFFER_HDR, tileTex, t).rgb;// / exposure;
            float lum = textureLod(BUFFER_LUMINANCE, tileTex, t).r;
            //lum = max(exp2(lum) - EPSILON, 0.0);
        #endif

        lum = max(exp2(lum) - EPSILON, 0.0) * exposure;

        float threshold = BLOOM_THRESHOLD;
        if (isEyeInWater == 1) threshold *= 6.0;

        lum = pow(lum * threshold, BLOOM_POWER) * 10.0;// * exp2(3.0 + 0.5*tile);
        //lum = min(lum, 1.0);
        lum = lum / (lum + 1.0);
        ChangeLuminance(final, lum);
    }

    outColor0 = final;
}
