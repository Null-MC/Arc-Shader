#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_BLOCK

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
flat out mat2 atlasBounds;
flat out int materialId;

#ifdef PARALLAX_ENABLED
    out vec2 localCoord;
    out vec3 tanViewPos;

    #if defined WORLD_SKY_ENABLED && defined SHADOW_ENABLED
        out vec3 tanLightPos;
    #endif
#endif

#ifdef WORLD_SKY_ENABLED
    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;
    #endif
#endif

#ifdef AF_ENABLED
    out vec4 spriteBounds;
#endif

attribute vec3 mc_Entity;
attribute vec4 at_tangent;

#if defined PARALLAX_ENABLED || defined AF_ENABLED
    attribute vec4 mc_midTexCoord;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int worldTime;

#include "/lib/celestial/position.glsl"
#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    materialId = int(mc_Entity.x + 0.5);

    BasicVertex(localPos);
    PbrVertex(viewPos);
}
