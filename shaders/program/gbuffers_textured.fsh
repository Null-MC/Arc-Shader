#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_TEXTURED

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 localPos;
in vec3 viewPos;
in vec3 viewNormal;
flat in float exposure;

#ifdef HANDLIGHT_ENABLED
    flat in vec3 blockLightColor;
#endif

#if defined HANDLIGHT_ENABLED || CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in vec2 skyLightLevels;
    flat in vec3 skyLightColor;

    uniform sampler2D colortex9;

    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform float wetness;
    uniform vec3 skyColor;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;
    
        #if SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform sampler2D shadowtex0;
            uniform sampler2D shadowtex1;

            #if defined SHADOW_ENABLE_HWCOMP && defined IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                uniform sampler2DShadow shadowtex1HW;
            #endif

            #ifdef SHADOW_COLOR
                uniform sampler2D shadowcolor0;
            #endif

            #ifdef SSS_ENABLED
                uniform usampler2D shadowcolor1;
            #endif
            
            uniform mat4 shadowModelView;
            uniform mat4 gbufferModelViewInverse;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                flat in float cascadeSizes[4];
                flat in vec3 matShadowProjections_scale[4];
                flat in vec3 matShadowProjections_translation[4];
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                uniform mat4 shadowProjection;
            #endif

            #if defined VL_ENABLED && defined VL_PARTICLES
                uniform float viewWidth;
                uniform float viewHeight;
            #endif
        #endif
    #endif
#endif

uniform sampler2D gtexture;
uniform sampler2D lightmap;

uniform ivec2 eyeBrightnessSmooth;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int fogMode;

#if MC_VERSION >= 11700 && defined IS_OPTIFINE
    uniform float alphaTestRef;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef IS_OPTIFINE
    uniform float eyeHumidity;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#ifdef SKY_ENABLED
    #include "/lib/world/scattering.glsl"
    #include "/lib/world/sky.glsl"
#endif

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/basic_handlight.glsl"
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    #if SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/sampling/bayer.glsl"

        #if SHADOW_PCF_SAMPLES == 12
            #include "/lib/sampling/poisson_12.glsl"
        #elif SHADOW_PCF_SAMPLES == 24
            #include "/lib/sampling/poisson_24.glsl"
        #elif SHADOW_PCF_SAMPLES == 36
            #include "/lib/sampling/poisson_36.glsl"
        #endif
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif

    #if defined VL_ENABLED && defined VL_PARTICLES
        #include "/lib/lighting/volumetric.glsl"
    #endif
#endif

#include "/lib/world/fog.glsl"
#include "/lib/world/sun.glsl"
#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/basic_forward.glsl"

/* RENDERTARGETS: 4,6 */
//out vec4 outColor0;
//out vec4 outColor1;


void main() {
    LightData lightData;
    lightData.occlusion = 1.0;
    lightData.blockLight = lmcoord.x;
    lightData.skyLight = lmcoord.y;
    lightData.geoNoL = geoNoL;
    lightData.parallaxShadow = 1.0;

    // TODO: screen depths

    #ifdef SKY_ENABLED
        float worldY = localPos.y + cameraPosition.y;
        lightData.skyLightLevels = skyLightLevels;
        lightData.sunTransmittance = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);
    #endif

    // TODO: shadow data

    vec4 color = BasicLighting(lightData);

    vec4 outLuminance = vec4(0.0);
    outLuminance.r = log2(luminance(color.rgb) + EPSILON);
    outLuminance.a = color.a;
    gl_FragData[1] = outLuminance;

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    gl_FragData[0] = color;
}
