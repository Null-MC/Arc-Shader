#define RENDER_FRAG
#define RENDER_ARMOR_GLINT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;

uniform sampler2D lightmap;
uniform sampler2D gtexture;

/* RENDERTARGETS: 0 */
out vec4 outColor0;


void main() {
    vec4 color = texture(gtexture, texcoord);
    color.rgb *= glcolor.rgb;

    color *= texture(lightmap, lmcoord);

    #if !defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE
        color.rgb *= glcolor.a;
    #endif

    outColor0 = color;
}
