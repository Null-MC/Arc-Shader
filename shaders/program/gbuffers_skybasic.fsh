#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec3 starData;
flat in vec3 sunTransmittance;
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
    //uniform float eyeHumidity;
    uniform int worldTime;
#endif
    uniform float eyeHumidity;

#if ATMOSPHERE_TYPE == ATMOSPHERE_TYPE_FANCY
    uniform sampler2D noisetex;

    uniform mat4 gbufferModelViewInverse;
    uniform float frameTimeCounter;
    uniform float eyeAltitude;

    #include "/lib/world/atmosphere.glsl"
#endif

#include "/lib/sampling/bayer.glsl"
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
        vec2 skyLightLevels = GetSkyLightLevels();

        vec3 localSunPos = mat3(gbufferModelViewInverse) * sunPosition;
        vec3 localSunDir = normalize(localSunPos);

        vec3 localViewPos = mat3(gbufferModelViewInverse) * viewPos;
        vec3 localViewDir = normalize(localViewPos);

        ScatteringParams setting;
        setting.sunRadius = 3000.0;
        setting.sunRadiance = 0.1 * skyLightLevels.x * sunLumen;
        setting.mieG = 0.96;
        setting.mieHeight = 1200.0;
        setting.rayleighHeight = 8000.0;
        setting.earthRadius = 6360000.0;
        setting.earthAtmTopRadius = 6420000.0;
        setting.earthCenter = vec3(0.0, -6360000.0, 0.0);
        setting.waveLambdaMie = vec3(2e-7);
        
        // wavelength with 680nm, 550nm, 450nm
        setting.waveLambdaRayleigh = ComputeWaveLambdaRayleigh(vec3(680e-9, 550e-9, 450e-9));
        
        // see https://www.shadertoy.com/view/MllBR2
        setting.waveLambdaOzone = vec3(1.36820899679147, 3.31405330400124, 0.13601728252538) * 0.6e-6 * 2.504;

        vec3 eye = vec3(0.0, 200.0 * eyeAltitude, 0.0);

        vec3 sky = ComputeSkyInscattering(setting, eye, localViewDir, localSunDir).rgb;

        //vec3 sky = GetSkyColor(localViewDir, localSunDir) * 1000.0;

        color += sky;
        lum += luminance(sky);
    #else
        vec3 viewDir = normalize(viewPos);
        vec3 sky = GetVanillaSkyLuminance(viewDir);

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && defined VL_ENABLED
            //sky += GetVanillaSkyScattering(viewDir, sunLightLevel, sunTransmittanceLux, moonColor);
            vec2 skyLightLevels = GetSkyLightLevels();
            float scattering = GetScatteringFactor(skyLightLevels.x);
            vec3 vlColor = vec3(0.0);

            vec3 sunDir = normalize(sunPosition);
            float sun_VoL = dot(viewDir, sunDir);
            float sunScattering = ComputeVolumetricScattering(sun_VoL, scattering);
            vlColor += sunScattering * sunTransmittance * GetSunLux();

            vec3 moonDir = normalize(moonPosition);
            float moon_VoL = dot(viewDir, moonDir);
            float moonScattering = ComputeVolumetricScattering(moon_VoL, scattering);
            vlColor += moonScattering * moonColor;

            sky += vlColor;
        #endif
        
        lum += luminance(sky);
        color += sky;
    #endif

    #ifdef SKY_DITHER
        float offset = 0.1;//lum / (lum + 1.0);
        float b = GetScreenBayerValue();
        color *= (1.0 - offset) + offset * b;
        //lum -= b;
    #endif

    outColor1 = log2(lum + EPSILON);
    outColor0 = clamp(color * exposure, vec3(0.0), vec3(65000));
}
