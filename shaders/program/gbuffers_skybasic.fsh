#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec3 starData;
flat in float sunLightLevel;
flat in vec3 sunColor;
flat in vec3 moonColor;
flat in float exposure;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float near;
uniform float far;
    
uniform int isEyeInWater;
uniform float rainStrength;
uniform float wetness;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform int moonPhase;

#ifdef IS_OPTIFINE
    uniform float eyeHumidity;
    uniform int worldTime;
#endif

#if ATMOSPHERE_TYPE == ATMOSPHERE_TYPE_FANCY
    uniform mat4 gbufferModelViewInverse;
    uniform float eyeAltitude;
    uniform float near;

    #include "/lib/world/atmosphere.glsl"
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/world/scattering.glsl"

/* RENDERTARGETS: 4,6 */
out vec3 outColor0;
out float outColor1;


void main() {
    vec3 color = starData;
    float lum = luminance(starData) * StarLumen;

    vec3 clipPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0) * 2.0 - 1.0;
    vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

    #if ATMOSPHERE_TYPE == ATMOSPHERE_TYPE_FANCY
        vec3 localSunPos = mat3(gbufferModelViewInverse) * sunPosition;
        vec3 localSunDir = normalize(localSunPos);

        vec3 localViewPos = mat3(gbufferModelViewInverse) * viewPos;

        ScatteringParams setting;
        setting.sunRadius = 3000.0;
        setting.sunRadiance = sunLightLevel * sunLumen;
        setting.mieG = 0.96;
        setting.mieHeight = 1200.0;
        setting.rayleighHeight = 8000.0;
        setting.earthRadius = 6360000.0;
        setting.earthAtmTopRadius = 6420000.0;
        setting.earthCenter = vec3(0.0, -6360000.0, 0.0);
        setting.waveLambdaMie = vec3(2e-7);

        vec3 localViewDir = normalize(localViewPos);
        
        // wavelength with 680nm, 550nm, 450nm
        setting.waveLambdaRayleigh = ComputeWaveLambdaRayleigh(vec3(680e-9, 550e-9, 450e-9));
        
        // see https://www.shadertoy.com/view/MllBR2
        setting.waveLambdaOzone = vec3(1.36820899679147, 3.31405330400124, 0.13601728252538) * 0.6e-6 * 2.504;

        vec3 eye = vec3(0.0, 200.0 * eyeAltitude, 0.0);

        vec4 sky = ComputeSkyInscattering(setting, eye, localViewDir, localSunDir);

        color += sky.rgb;
        lum += luminance(sky.rgb);
    #else
        vec3 viewDir = normalize(viewPos);
        vec3 sky = GetVanillaSkyLuminance(viewDir);
        sky += GetVanillaSkyScattering(viewDir, sunColor, moonColor);
        lum += luminance(sky);
        color += sky;
    #endif

    outColor1 = log2(lum + EPSILON);
    outColor0 = clamp(color * exposure, vec3(0.0), vec3(65000));
}