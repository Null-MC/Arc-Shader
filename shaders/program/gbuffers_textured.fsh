#define RENDER_TEXTURED
#define RENDER_GBUFFER
#define RENDER_FRAG

//#undef PARALLAX_ENABLED
//#undef AF_ENABLED

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
flat in int materialId;

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

#if MC_VERSION >= 11700 && SHADER_PLATFORM != PLATFORM_IRIS
    uniform float alphaTestRef;
#endif

#include "/lib/material/material.glsl"

#include "/lib/material/material_reader.glsl"
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
