#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_BASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 viewPos;
in vec3 viewNormal;
in vec3 viewTangent;
flat in float tangentW;
flat in mat2 atlasBounds;

/* RENDERTARGETS: 0 */
layout(location = 0) out uvec4 outColor0;


void main() {
    vec4 colorMap, normalMap, specularMap, lightingMap;
    //PbrLighting(colorMap, normalMap, specularMap, lightingMap);
    colorMap = vec4(0.0, 0.0, 0.0, 0.0);
    normalMap = vec4(0.0, 0.0, 1.0, 0.0);
    specularMap = vec4(0.0, 0.0, 0.0, 0.0);
    lightingMap = vec4(0.0, 0.0, 1.0, 1.0);

    uvec4 data;
    data.r = packUnorm4x8(colorMap);
    data.g = packUnorm4x8(normalMap);
    data.b = packUnorm4x8(specularMap);
    data.a = packUnorm4x8(lightingMap);
    outColor0 = data;
}
