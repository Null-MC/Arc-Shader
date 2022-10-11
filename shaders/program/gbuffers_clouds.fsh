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

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;

#include "/lib/lighting/blackbody.glsl"
#include "/lib/world/scattering.glsl"
#include "/lib/world/sun.glsl"
#include "/lib/world/sky.glsl"


void main() {
    vec4 colorMap = texture(gtexture, texcoord);
    colorMap.rgb = RGBToLinear(colorMap.rgb);// * glcolor.rgb);

    if (colorMap.a < alphaTestRef) discard;

    float viewDist = length(viewPos);
    float distF = saturate(viewDist * 0.02);
    colorMap.a = 0.1 + 0.9 * smoothstep(0.0, 1.0, distF);

    //float darkness = 0.7 - 0.55 * rainStrength;
    float worldY = localPos.y + cameraPosition.y;
    vec3 sunTransmittanceLux = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);
    sunTransmittanceLux *= GetSunLux();// * darkness;
    //colorMap.rgb *= sunTransmittanceLux;

    //vec3 moonColor = vec3(0.0); // TODO: assign in vertex
    //float rayLen = min(viewDist / (101.0 - VL_STRENGTH), 1.0);

    //colorMap.rgb *= GetVanillaSkyScattering(viewDir, skyLightLevels.x, sunTransmittanceLux, moonColor) * rayLen;
    #ifdef IS_OPTIFINE
        vec3 sunLightDir = GetFixedSunPosition();
    #else
        vec3 sunLightDir = normalize(sunPosition);
    #endif

    vec3 viewDir = normalize(viewPos);
    float sun_VoL = dot(viewDir, sunLightDir);
    float sun_G = mix(G_SCATTERING_CLOUDS, G_SCATTERING_RAIN_CLOUDS, rainStrength);
    float sunScattering = ComputeVolumetricScattering(sun_VoL, sun_G);
    //colorMap.rgb *= GetVanillaSkyScattering(viewDir, skyLightLevels.x, sunTransmittanceLux, moonColor) * rayLen;
    //vec3 vlColor = (sunScattering * sunColor + moonScattering * moonColor) * scatterDistF;
    //float scatterDistF = min(viewDist / (101.0 - VL_STRENGTH), 1.0);
    vec3 vlColorLux = sunScattering * sunTransmittanceLux;

    //float skyLux = mix(2.0*NightSkyLux, 0.75*DaySkyLux, saturate(skyLightLevels.x));
    float skyLux = smoothstep(0.0, 1.0, saturate(skyLightLevels.x)) * 3000.0 + 8.0;

    colorMap.rgb *= (skyLux + vlColorLux) * (1.0 - 0.96*rainStrength);

    //colorMap.a = pow(colorMap.a, 0.2);

    vec4 lum = vec4(0.0);
    lum.r = log2(luminance(colorMap.rgb) + EPSILON);
    lum.a = colorMap.a;
    outColor1 = lum;

    colorMap.rgb = clamp(colorMap.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = colorMap;
}
