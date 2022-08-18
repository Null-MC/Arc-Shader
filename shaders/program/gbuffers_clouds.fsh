#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_CLOUDS

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;
flat in float exposure;

uniform sampler2D gtexture;

uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float near;
uniform float far;

uniform float rainStrength;
uniform float wetness;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform int moonPhase;

#ifdef IS_OPTIFINE
    uniform float eyeHumidity;

    #if MC_VERSION >= 11700
        uniform float alphaTestRef;
    #endif
#endif

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;

#include "/lib/lighting/blackbody.glsl"
#include "/lib/world/scattering.glsl"
#include "/lib/world/sky.glsl"


void main() {
    vec4 colorMap = texture(gtexture, texcoord);
    colorMap.rgb = RGBToLinear(colorMap.rgb * glcolor.rgb);

    if (colorMap.a < alphaTestRef) discard;

    float viewDist = length(viewPos);
    float distF = saturate(viewDist * 0.02);
    colorMap.a = 0.2 + 0.7 * smoothstep(0.0, 1.0, distF);

    vec2 skyLightLevels = GetSkyLightLevels();
    float darkness = 0.7 - 0.3 * rainStrength;
    colorMap.rgb *= GetSkyLightLuminance(skyLightLevels) * darkness;

    vec4 lum = vec4(0.0);
    lum.r = log2(luminance(colorMap.rgb) + EPSILON);
    lum.a = colorMap.a;
    outColor1 = lum;

    colorMap.rgb = clamp(colorMap.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = colorMap;
}
