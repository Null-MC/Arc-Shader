#define RENDER_VERTEX
#define RENDER_DEFERRED
//#define RENDER_DEFERRED_REFRACT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

void main() {
    gl_Position = ftransform();
}
