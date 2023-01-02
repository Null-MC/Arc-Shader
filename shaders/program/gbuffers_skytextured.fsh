#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec4 glcolor;
in vec2 texcoord;
flat in float exposure;
flat in vec3 sunColor;
flat in vec3 moonColor;
flat in vec3 sunTransmittanceEye;
flat in vec3 moonTransmittanceEye;

uniform sampler2D gtexture;

uniform int renderStage;
uniform float rainStrength;

/* RENDERTARGETS: 4,6 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;


void main() {
    vec3 color = textureLod(gtexture, texcoord, 0).rgb;
    color = RGBToLinear(color * glcolor.rgb);

    float lum = luminance(color);
    if (lum < EPSILON) discard;
    float alpha = saturate(lum);

    float lumF = 1.0;

    if (renderStage == MC_RENDER_STAGE_SUN) {
        lumF = sunLumen;
        color *= sunColor * sunTransmittanceEye * 100000.0 * (1.0 - 0.7 * rainStrength);//sunLumen
        lum *= luminance(sunColor * sunTransmittanceEye);
        alpha *= min(luminance(sunTransmittanceEye), 1.0);
    }
    else if (renderStage == MC_RENDER_STAGE_MOON) {
        lumF = moonLumen;
        color *= moonColor * moonTransmittanceEye * moonLumen;
        lum *= luminance(moonColor * moonTransmittanceEye);
        alpha *= min(luminance(moonTransmittanceEye), 1.0);
    }
    else if (renderStage == MC_RENDER_STAGE_CUSTOM_SKY) {
        lumF = 1.0;
        color *= 10000.0 * (1.0 - 0.7 * rainStrength);
        lum = 10000.0 * (1.0 - 0.7 * rainStrength);
        //color = vec3(1000.0, 0.0, 0.0);
        //lum = 10.0;
    }

    color = clamp(color * exposure, vec3(0.0), vec3(65000));
    outColor0 = vec4(color, alpha);

    float lumFinal = log2(lum * lumF + EPSILON);
    outColor1 = vec4(lumFinal, 0.0, 0.0, alpha);
}
