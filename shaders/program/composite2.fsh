#define RENDER_FRAG
#define RENDER_COMPOSITE
#define RENDER_COMPOSITE_BLOOM_BLUR
//#define RENDER_COMPOSITE_BLOOM_BLUR_H

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
flat in int tileCount;

uniform sampler2D BUFFER_BLOOM;

uniform float viewWidth;
uniform float viewHeight;

#include "/lib/camera/bloom.glsl"

const vec2 direction = vec2(1.0, 0.0);

/* RENDERTARGETS: 7 */
out vec3 outColor0;


void main() {
    vec2 tileMin, tileMax;
    int tile = GetBloomTileInnerIndex(tileCount, tileMin, tileMax);

    vec3 final = vec3(0.0);
    if (tile >= 0) final = BloomBlur13(texcoord, tileMin, tileMax, direction);

    outColor0 = final;
}
