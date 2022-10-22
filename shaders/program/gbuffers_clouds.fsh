#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_CLOUDS

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;
in vec3 localPos;
flat in float exposure;
flat in vec2 skyLightLevels;
flat in vec3 sunTransmittanceEye;
flat in vec3 moonColor;

uniform sampler2D gtexture;
uniform sampler2D colortex9;

uniform mat4 gbufferModelViewInverse;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float near;
uniform float far;

uniform float rainStrength;
uniform int isEyeInWater;
uniform float wetness;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;

uniform int fogShape;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;

uniform float eyeHumidity;

#ifdef IS_OPTIFINE
    uniform mat4 gbufferModelView;
    //uniform float eyeHumidity;
    uniform int worldTime;

    #if MC_VERSION >= 11700
        uniform float alphaTestRef;
    #endif
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;

#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"
#include "/lib/world/sun.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/world/scattering.glsl"
#include "/lib/world/fog.glsl"


void main() {
    vec4 colorMap = texture(gtexture, texcoord);
    colorMap.rgb = RGBToLinear(colorMap.rgb);// * glcolor.rgb);

    if (colorMap.a < alphaTestRef) discard;

    float viewDist = length(viewPos);
    vec3 viewDir = normalize(viewPos);
    float distF = saturate(viewDist * 0.02);
    float worldY = localPos.y + cameraPosition.y;

    vec4 finalColor;
    finalColor.a = 0.1 + 0.5 * smoothstep(0.0, 1.0, distF);

    //lightLevel = smoothstep(0.2, 1.0, lightLevel) * 8000.0 + 500.0;
    //float skyLux = smoothstep(0.2, 1.0, saturate(skyLightLevels.x)) * 5000.0 + 300.0;
    float scatter_G = mix(G_SCATTERING_CLOUDS, G_SCATTERING_RAIN_CLOUDS, rainStrength);

    #ifdef IS_OPTIFINE
        vec3 sunDir = GetFixedSunPosition();
    #else
        vec3 sunDir = normalize(sunPosition);
    #endif

    float sun_VoL = dot(viewDir, sunDir);
    float sunScattering = ComputeVolumetricScattering(sun_VoL, scatter_G);
    vec3 sunTransmittance = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);
    finalColor.rgb += saturate(sunScattering) * sunTransmittance * GetSunLux();

    vec3 moonDir = normalize(moonPosition);
    float moon_VoL = dot(viewDir, moonDir);
    float moonScattering = ComputeVolumetricScattering(moon_VoL, scatter_G);
    finalColor.rgb += saturate(moonScattering) * moonColor;

    LightData lightData;
    lightData.skyLight = 1.0;
    lightData.skyLightLevels = skyLightLevels;
    //lightData.sunTransmittance = sunTransmittance;
    lightData.sunTransmittanceEye = sunTransmittanceEye;
    //float fogFactor = ApplyFog(finalColor.rgb, viewPos, lightData);

    //vec3 sunColorFinal = sunTransmittanceEye * GetSunLux(); // * sunColor;
    //vec3 vlColor = GetVanillaSkyScattering(viewDir, skyLightLevels, sunColorFinal, moonColor);
    //finalColor.rgb += vlColor * fogFactor;

    vec4 lum = vec4(0.0);
    lum.r = log2(luminance(finalColor.rgb) + EPSILON);
    lum.a = finalColor.a;
    outColor1 = lum;

    finalColor.rgb = clamp(finalColor.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = finalColor;
}
