#define RENDER_SKYTEXTURED
#define RENDER_GBUFFER
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec4 glcolor;
in vec2 texcoord;

#ifndef IRIS_FEATURE_SSBO
    flat in float sceneExposure;

    flat in vec3 skySunColor;
    flat in vec3 sunTransmittanceEye;

    #ifdef WORLD_MOON_ENABLED
        flat in vec3 skyMoonColor;
        flat in vec3 moonTransmittanceEye;
    #endif
#endif

uniform sampler2D gtexture;

uniform int renderStage;
uniform float rainStrength;

/* RENDERTARGETS: 4,3 */
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
        color *= skySunColor * sunTransmittanceEye * 100000.0 * (1.0 - 0.7 * rainStrength);//sunLumen
        lum *= luminance(skySunColor * sunTransmittanceEye);
        alpha *= min(luminance(sunTransmittanceEye), 1.0);
    }
    else if (renderStage == MC_RENDER_STAGE_MOON) {
        lumF = moonLumen;
        color *= skyMoonColor * moonTransmittanceEye * moonLumen;
        lum *= luminance(skyMoonColor * moonTransmittanceEye);
        alpha *= min(luminance(moonTransmittanceEye), 1.0);
    }
    else if (renderStage == MC_RENDER_STAGE_CUSTOM_SKY) {
        lumF = 1.0;
        color *= 10000.0 * (1.0 - 0.7 * rainStrength);
        lum = 10000.0 * (1.0 - 0.7 * rainStrength);
        //color = vec3(1000.0, 0.0, 0.0);
        //lum = 10.0;
    }

    color = clamp(color * sceneExposure, vec3(0.0), vec3(65000));
    outColor0 = vec4(color, alpha);

    float lumFinal = log2(lum * lumF + EPSILON);
    outColor1 = vec4(lumFinal, 0.0, 0.0, alpha);
}
