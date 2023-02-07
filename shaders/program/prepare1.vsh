#define RENDER_PREPARE_SKY_LUT
#define RENDER_PREPARE
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out vec3 localSunDir;

uniform mat4 gbufferModelView;
uniform int worldTime;

#ifdef IS_IRIS
    uniform mat4 gbufferModelViewInverse;

    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 shadowLightPosition;
#endif

#include "/lib/celestial/position.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    localSunDir = GetSunLocalDir();
}
