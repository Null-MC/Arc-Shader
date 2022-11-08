#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_CLOUDS

#include "/lib/constants.glsl"
#include "/lib/common.glsl"


void main() {
    // Force offscreen to prevent from being force-rendered by player config
    gl_Position = vec4(10.0);
}
