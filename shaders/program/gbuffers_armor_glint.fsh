#define RENDER_FRAG
#define RENDER_ARMOR_GLINT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;

uniform sampler2D lightmap;
uniform sampler2D gtexture;

/* RENDERTARGETS: 2,1 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;


void main() {
    outColor0 = vec4(2000.0, 0.0, 0.0, 1.0);
    return;

    vec4 color = texture(gtexture, texcoord) * glcolor;

    float lum = saturate(luminance(color.rgb));
    color.a = smoothstep(0.2, 0.75, lum);//pow2(color.a);

    color.rgb *= 2200.0;
    //color *= texture(lightmap, lmcoord);

    // #if !defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE
    //     color.rgb *= glcolor.a;
    // #endif

    vec4 outLum = vec4(0.0);
    outLum.r = log2(luminance(color.rgb) + EPSILON);
    outLum.a = color.a;
    outColor1 = outLum;

    color.rgb = clamp(color.rgb * sceneExposure, vec3(0.0), vec3(65000));

    outColor0 = color;
}
