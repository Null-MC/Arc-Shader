#define RENDER_VERTEX
#define RENDER_COMPOSITE
#define RENDER_COMPOSITE_BLOOM_BLUR
//#define RENDER_COMPOSITE_BLOOM_BLUR_V

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out int tileCount;

uniform sampler2D BUFFER_HDR;

uniform float viewWidth;
uniform float viewHeight;

#include "/lib/camera/bloom.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    vec2 viewSize = vec2(viewWidth, viewHeight);
    tileCount = GetBloomTileCount(viewSize);
}
