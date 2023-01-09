#define RENDER_PREPARE
#define RENDER_VERTEX
//#define RENDER_SKY_LUT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
flat out vec3 localSunDir;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        localSunDir = mat3(gbufferModelViewInverse) * GetFixedSunPosition();
    #else
        localSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    #endif
}
