#define RENDER_TEXTURED
#define RENDER_GBUFFER
#define RENDER_VERTEX

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 localPos;
out vec3 viewPos;
out vec3 viewNormal;
out vec3 viewTangent;
flat out float tangentW;
flat out int materialId;

attribute vec4 at_tangent;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    localPos = gl_Vertex.xyz;
    BasicVertex(localPos);
    PbrVertex(viewPos);
}
