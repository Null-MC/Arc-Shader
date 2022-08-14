#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_BEACONBEAM

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

#undef PARALLAX_ENABLED
#undef SHADOW_ENABLED

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;
in vec3 viewNormal;
in float geoNoL;
in mat3 matTBN;
in vec3 tanViewPos;

#ifdef AF_ENABLED
    in vec4 spriteBounds;
#endif

uniform sampler2D gtexture;

#if MC_VERSION >= 11700 && defined IS_OPTIFINE
    uniform float alphaTestRef;
#endif

#ifdef AF_ENABLED
	uniform float viewHeight;
#endif

/* RENDERTARGETS: 2 */
out uvec4 outColor0;


void main() {
	vec4 colorMap;
    #ifdef PARALLAX_ENABLED
		colorMap = textureAF(gtexture, texcoord);
    #else
		colorMap = texture(gtexture, texcoord);
    #endif

    if (colorMap.a < 0.98) discard;
    colorMap.a = 1.0;

    colorMap.rgb *= glcolor.rgb;

    #if !defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE
        colorMap.rgb *= glcolor.a;
    #endif

	vec4 normalMap = vec4(viewNormal, 1.0);
	vec4 specularMap = vec4(0.0, 0.02, 0.0, 0.9);
	vec4 lightingMap = vec4(1.0, 0.0, 1.0, 0.0);

    outColor0.r = packUnorm4x8(colorMap);
    outColor0.g = packUnorm4x8(normalMap);
    outColor0.b = packUnorm4x8(specularMap);
    outColor0.a = packUnorm4x8(lightingMap);
}
