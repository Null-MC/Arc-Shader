#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
in vec4 glcolor;
//flat in vec2 skyLightLevels;
flat in vec3 sunTransmittance;
flat in float sunLightLevel;
flat in float moonLightLevel;
//flat in vec3 sunLightLumColor;
flat in vec3 moonLightLumColor;
flat in float exposure;

uniform sampler2D gtexture;

uniform int renderStage;

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;


void main() {
    vec3 color = textureLod(gtexture, texcoord, 0).rgb;
    color = RGBToLinear(color * glcolor.rgb);

    float lum = saturate(luminance(color));
    if (lum < EPSILON) discard;

    float lumF = 0.0;

    if (renderStage == MC_RENDER_STAGE_SUN) {
        lumF += sunLumen;// * sunLightLevel;//luminance(sunTransmittanceLum);
        color *= sunTransmittance * 10000.0;
        lum *= sunLightLevel;
    }
    else if (renderStage == MC_RENDER_STAGE_MOON) {
        lumF += moonLumen;
        color *= moonLightLumColor * moonLightLevel * 0.1;
        lum *= moonLightLevel;
    }

    float alpha = saturate(lum);

    color = clamp(color * exposure, vec3(0.0), vec3(65000));
    outColor0 = vec4(color, alpha);

    float lumFinal = log2(lum * lumF + EPSILON);
    outColor1 = vec4(lumFinal, 0.0, 0.0, alpha);
}
