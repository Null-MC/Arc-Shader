#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_BASIC

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

uniform sampler2D gtexture;

uniform vec3 cameraPosition;
uniform int renderStage;

#if MC_VERSION >= 11700
    uniform float alphaTestRef;
#endif

#include "/lib/lighting/basic_gbuffers.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out uvec4 outColor0;


void main() {
    vec4 colorMap, normalMap, specularMap, lightingMap;
    colorMap = vec4(0.0, 0.0, 0.0, 0.0);
    normalMap = vec4(0.5, 0.5, 1.0, 1.0);
    specularMap = vec4(0.0, 0.0, 0.0, 0.0);
    lightingMap = vec4(1.0, 1.0, 1.0, 1.0);

    if (renderStage == MC_RENDER_STAGE_OUTLINE) {
        #if BLOCK_OUTLINE == BLOCK_OUTLINE_WHITE
            colorMap.rgb = vec3(0.8);
        #elif BLOCK_OUTLINE == BLOCK_OUTLINE_FANCY
            vec3 worldPos = fract(cameraPosition) + localPos;
            float offset = (worldPos.x + worldPos.y + worldPos.z) * 10.0;
            colorMap.rgb = step(1.0, mod(offset, 2.0)) * vec3(1.0, 1.0, 0.0);
            specularMap.a = 0.06;
        #endif
    }
    else {
        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        BasicLighting(dFdXY, colorMap);
    }

    uvec4 data;
    data.r = packUnorm4x8(colorMap);
    data.g = packUnorm4x8(normalMap);
    data.b = packUnorm4x8(specularMap);
    data.a = packUnorm4x8(lightingMap);
    outColor0 = data;
}
