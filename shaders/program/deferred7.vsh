//#define RENDER_DEFERRED_REFRACT
#define RENDER_DEFERRED
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"


void main() {
    gl_Position = ftransform();
}
