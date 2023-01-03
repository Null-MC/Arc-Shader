#define RENDER_COMPOSITE_WATER_BLUR_H
#define RENDER_COMPOSITE
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

uniform int isEyeInWater;


void main() {
    if (isEyeInWater != 1) {
        gl_Position = vec4(-10.0);
        return;
    }

    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
