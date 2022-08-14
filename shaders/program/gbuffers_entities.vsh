#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_ENTITIES

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec4 at_tangent;

#if defined PARALLAX_ENABLED || defined AF_ENABLED
    in vec4 mc_midTexCoord;
#endif

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 viewPos;
out vec3 viewNormal;
out vec3 viewTangent;
flat out float tangentW;
flat out mat2 atlasBounds;

#ifdef AF_ENABLED
    out vec4 spriteBounds;
#endif

#ifdef PARALLAX_ENABLED
    out vec2 localCoord;
    out vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        out vec3 tanLightPos;
    #endif
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    uniform vec3 shadowLightPosition;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int entityId;

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    vec3 localPos = gl_Vertex.xyz;
    BasicVertex(localPos);
    
    // No PBR for lightning
    if (entityId != 100.0)
        PbrVertex(viewPos);
}
