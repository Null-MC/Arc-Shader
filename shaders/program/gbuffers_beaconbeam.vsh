#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_BEACONBEAM

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

#undef PARALLAX_ENABLED
#undef SHADOW_ENABLED

out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 viewPos;
out vec3 viewNormal;
out vec3 tanViewPos;
out mat3 matTBN;

#ifdef AF_ENABLED
    out vec4 spriteBounds;
#endif

in vec4 at_tangent;

#ifdef AF_ENABLED
    in vec4 mc_midTexCoord;
#endif

#include "/lib/lighting/basic.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    vec3 localPos = gl_Vertex.xyz;
    BasicVertex(localPos);
}
