#define RENDER_ENTITIES_OPAQUE
#define RENDER_ENTITIES
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
uniform vec4 entityColor;
uniform int entityId;

#ifdef WORLD_SKY_ENABLED
    uniform vec3 upPosition;
    uniform float wetness;
#endif

#if MC_VERSION >= 11700
    uniform float alphaTestRef;
#endif
    
#include "/lib/atlas.glsl"
#include "/lib/blocks.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/material/material.glsl"

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    #include "/lib/material/entity_default.glsl"
#endif

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#include "/lib/physicsMod/snow.glsl"

#include "/lib/world/weather.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/basic_gbuffers.glsl"
#include "/lib/lighting/pbr_gbuffers.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out uvec4 outColor0;


void main() {
    vec4 colorMap, normalMap, specularMap, lightingMap;

    if (entityId == ENTITY_LIGHTNING_BOLT) {
        colorMap = vec4(1.0);
        normalMap = vec4(0.0, 0.0, 1.0, 1.0);
        specularMap = vec4(0.0, 0.0, 0.0, 254.0/255.0);
        lightingMap = vec4(1.0);
    }
    else {
        PbrLighting(colorMap, normalMap, specularMap, lightingMap);
    }

    uvec4 data;
    data.r = packUnorm4x8(colorMap);
    data.g = packUnorm4x8(normalMap);
    data.b = packUnorm4x8(specularMap);
    data.a = packUnorm4x8(lightingMap);
    outColor0 = data;
}
