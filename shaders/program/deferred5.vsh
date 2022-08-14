#define RENDER_VERTEX
#define RENDER_DEFERRED
#define RENDER_AO_BLUR

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
