#define RENDER_FRAG
#define RENDER_COMPOSITE
#define RENDER_COMPOSITE_BLOOM_BLUR
//#define RENDER_COMPOSITE_BLOOM_BLUR_V

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
flat in int tileCount;

uniform sampler2D BUFFER_BLOOM;

uniform float viewWidth;
uniform float viewHeight;

#include "/lib/camera/bloom.glsl"
#include "/lib/sampling/gaussian_7_bounded.glsl"

const vec2 direction = vec2(0.0, 1.0);

/* RENDERTARGETS: 2 */
layout(location = 0) out vec3 outColor0;


void main() {
    vec2 tileMin, tileMax;
    int tile = GetBloomTileInnerIndex(tileCount, tileMin, tileMax);

    vec3 final = vec3(0.0);
    if (tile >= 0) final = GaussianBlur13(BUFFER_BLOOM, texcoord, tileMin, tileMax, direction);

    outColor0 = final;
}
