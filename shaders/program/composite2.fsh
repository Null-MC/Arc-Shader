#define RENDER_FRAG
#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_TRANSPARENT_BLEND

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;


/* RENDERTARGETS: 4 */
out vec4 outColor0;


void main() {
    outColor0 = vec4(1.0);
}
