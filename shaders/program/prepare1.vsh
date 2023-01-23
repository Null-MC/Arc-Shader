#define RENDER_PREPARE_SKY_LUT
#define RENDER_PREPARE
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out vec3 localSunDir;

#if SHADER_PLATFORM == PLATFORM_OPTIFINE
    uniform int worldTime;
    uniform mat4 gbufferModelView;
#else
    uniform mat4 gbufferModelViewInverse;

    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
#endif

#include "/lib/celestial/position.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        localSunDir = GetFixedSunPosition();
    #else
        localSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    #endif
}
