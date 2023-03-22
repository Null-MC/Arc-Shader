#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_TERRAIN

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

#if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
    layout (depth_greater) out float gl_FragDepth;
#endif

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
    //uniform vec3 upPosition;
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

#if LAVA_TYPE == LAVA_FANCY
    uniform sampler3D TEX_CLOUD_NOISE;
#endif

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform ivec2 atlasSize;
uniform int isEyeInWater;
uniform float skyWetnessSmooth;
uniform float skySnowSmooth;
uniform float biomeWetnessSmooth;
uniform float biomeSnowSmooth;

#if MC_VERSION >= 11700
    uniform float alphaTestRef;
#endif

#ifdef AF_ENABLED
    #include "/lib/sampling/anisotropic.glsl"
#endif

#include "/lib/atlas.glsl"
#include "/lib/blocks.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/material/material.glsl"

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    #include "/lib/material/default.glsl"
#endif

#if LAVA_TYPE == LAVA_FANCY
    #include "/lib/world/lava.glsl"
#endif

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

    uvec4 data;
    data.r = packUnorm4x8(colorMap);
    data.g = packUnorm4x8(normalMap);
    data.b = packUnorm4x8(specularMap);
    data.a = packUnorm4x8(lightingMap);
    outColor0 = data;
}
