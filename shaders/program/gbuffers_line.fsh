#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_LINE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec3 localPos;

/* RENDERTARGETS: 2 */
layout(location = 0) out uvec4 outColor0;


void main() {
    vec4 colorMap = vec4(0.0, 0.0, 0.0, 1.0);
    vec4 normalMap = vec4(0.5, 0.5, 1.0, 0.0);
    vec4 specularMap = vec4(0.0, 0.0, 0.0, 0.0);
    vec4 lightingMap = vec4(0.0, 0.0, 1.0, 0.0);

    #if BLOCK_OUTLINE == BLOCK_OUTLINE_WHITE
        colorMap.rgb = vec3(0.8);
    #elif BLOCK_OUTLINE == BLOCK_OUTLINE_FANCY
        float offset = (localPos.x + localPos.y + localPos.z) * 10.0;
        colorMap.rgb = step(1.0, mod(offset, 2.0)) * vec3(1.0, 1.0, 0.0);
        specularMap.a = 0.06;
    #endif

    uvec4 data;
    data.r = packUnorm4x8(colorMap);
    data.g = packUnorm4x8(normalMap);
    data.b = packUnorm4x8(specularMap);
    data.a = packUnorm4x8(lightingMap);
    outColor0 = data;
}
