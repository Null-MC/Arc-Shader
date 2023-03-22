#define RENDER_HAND_OPAQUE
#define RENDER_HAND
#define RENDER_GBUFFER
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 localPos;
in vec3 viewPos;
in vec3 viewNormal;
in vec3 viewTangent;
flat in float tangentW;
flat in mat2 atlasBounds;
flat in int materialId;

#ifdef PARALLAX_ENABLED
    in vec2 localCoord;
    in vec3 tanViewPos;

    uniform mat4 gbufferProjection;

    #if defined WORLD_SKY_ENABLED && defined SHADOW_ENABLED
        in vec3 tanLightPos;
    #endif
#endif

#ifdef WORLD_SKY_ENABLED
    uniform vec3 upPosition;
    uniform float wetness;
#endif

#ifdef AF_ENABLED
    in vec4 spriteBounds;

    uniform float viewHeight;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;
uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform ivec2 atlasSize;

#if MC_VERSION >= 11700
    uniform float alphaTestRef;
#endif

#include "/lib/atlas.glsl"
#include "/lib/blocks.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/material/material.glsl"

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
    #include "/lib/lighting/directional.glsl"
#endif

#include "/lib/world/weather.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/basic_gbuffers.glsl"
#include "/lib/lighting/pbr_gbuffers.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out uvec4 outColor0;


void main() {
    vec4 colorMap, normalMap, specularMap, lightingMap;
    PbrLighting(colorMap, normalMap, specularMap, lightingMap);
    
    outColor0 = uvec4(
        packUnorm4x8(colorMap),
        packUnorm4x8(normalMap),
        packUnorm4x8(specularMap),
        packUnorm4x8(lightingMap));
}
