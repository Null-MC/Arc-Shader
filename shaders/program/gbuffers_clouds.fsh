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

uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float near;
uniform float far;

uniform float rainStrength;
uniform int isEyeInWater;
uniform float wetness;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int moonPhase;

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
#include "/lib/world/scattering.glsl"
#include "/lib/world/sun.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/world/fog.glsl"


void main() {
    vec4 colorMap = texture(gtexture, texcoord);
    colorMap.rgb = RGBToLinear(colorMap.rgb);// * glcolor.rgb);

    if (colorMap.a < alphaTestRef) discard;

    float viewDist = length(viewPos);
    float distF = saturate(viewDist * 0.02);
    colorMap.a = 0.1 + 0.9 * smoothstep(0.0, 1.0, distF);

    float skyLux = smoothstep(0.0, 1.0, saturate(skyLightLevels.x)) * 3000.0 + 8.0;

    vec4 finalColor = colorMap;
    finalColor.rgb *= skyLux * (1.0 - 0.96*rainStrength);

    LightData lightData;
    lightData.skyLight = 1.0;
    lightData.skyLightLevels = skyLightLevels;
    lightData.sunTransmittanceEye = sunTransmittanceEye;
    ApplyFog(finalColor, viewPos, lightData, EPSILON);

    // TODO: Add VL
    #ifdef IS_OPTIFINE
        vec3 sunLightDir = GetFixedSunPosition();
    #else
        vec3 sunLightDir = normalize(sunPosition);
    #endif

    vec3 viewDir = normalize(viewPos);
    float sun_VoL = dot(viewDir, sunLightDir);
    float sun_G = mix(G_SCATTERING_CLOUDS, G_SCATTERING_RAIN_CLOUDS, rainStrength);
    float sunScattering = ComputeVolumetricScattering(sun_VoL, sun_G);

    float worldY = localPos.y + cameraPosition.y;
    vec3 sunTransmittance = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);
    vec3 vlColorLux = saturate(sunScattering) * sunTransmittance * GetSunLux();

    //finalColor.rgb += vlColorLux;

    vec4 lum = vec4(0.0);
    lum.r = log2(luminance(finalColor.rgb) + EPSILON);
    lum.a = finalColor.a;
    outColor1 = lum;

    finalColor.rgb = clamp(finalColor.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = finalColor;
}
