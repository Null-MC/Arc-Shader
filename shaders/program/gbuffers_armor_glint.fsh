#define RENDER_FRAG
#define RENDER_ARMOR_GLINT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;

uniform sampler2D lightmap;
uniform sampler2D gtexture;

#ifndef IRIS_FEATURE_SSBO
    flat in float sceneExposure;
#endif

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/scene.glsl"
#endif


#ifdef CANTFIX
    /* RENDERTARGETS: 0 */
    layout(location = 0) out uvec4 outColor0;
#else
    /* RENDERTARGETS: 2,1 */
    layout(location = 0) out vec4 outColor0;
    layout(location = 1) out vec4 outColor1;
#endif

void main() {
    vec4 color = texture(gtexture, texcoord);
    color.rgb = RGBToLinear(color.rgb * glcolor.rgb * glcolor.a);

    #ifdef CANTFIX
        uvec4 data;
        data.r = packUnorm4x8(color);
        data.g = packUnorm4x8(vec4(0.5, 0.5, 1.0, 1.0));
        data.b = packUnorm4x8(vec4(1.0));
        data.a = packUnorm4x8(vec4(1.0));
        outColor0 = data;
    #else
        color.rgb *= 3000.0;
        
        float lum = luminance(color.rgb);
        color.a = 0.4 * smoothstep(0.0, 0.6, lum);

        vec4 outLum = vec4(0.0);
        outLum.r = log2(luminance(color.rgb) + EPSILON);
        outLum.a = color.a;
        outColor1 = outLum;

        color.rgb = clamp(color.rgb * sceneExposure, vec3(0.0), vec3(65000));

        outColor0 = color;
    #endif
}
