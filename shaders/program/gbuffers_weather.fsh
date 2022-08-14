#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_WEATHER

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;
in vec3 viewNormal;
in float geoNoL;
flat in float exposure;

#ifdef HANDLIGHT_ENABLED
    flat in vec3 blockLightColor;

    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    uniform float rainStrength;
    uniform vec3 skyColor;
    uniform float wetness;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        flat in vec3 sunColor;
        flat in vec3 moonColor;
        flat in vec3 skyLightColor;

        uniform vec3 shadowLightPosition;
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;

        #if SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform sampler2D shadowtex0;

            #ifdef SHADOW_COLOR
                uniform sampler2D shadowcolor0;
            #endif

            #ifdef SSS_ENABLED
                uniform usampler2D shadowcolor1;
            #endif

            #ifdef SHADOW_ENABLE_HWCOMP
                #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                    uniform sampler2DShadow shadowtex1HW;
                    uniform sampler2D shadowtex1;
                #else
                    uniform sampler2DShadow shadowtex1;
                #endif
            #else
                uniform sampler2D shadowtex1;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                flat in float cascadeSizes[4];
                flat in vec3 matShadowProjections_scale[4];
                flat in vec3 matShadowProjections_translation[4];
            #else
                uniform mat4 shadowProjection;
            #endif
            
            #if defined VL_ENABLED && defined VL_PARTICLES
                uniform mat4 shadowModelView;
                uniform mat4 gbufferModelViewInverse;
                uniform float viewWidth;
                uniform float viewHeight;
            #endif
        #endif
    #endif
#endif

uniform sampler2D gtexture;
uniform sampler2D lightmap;

uniform ivec2 eyeBrightnessSmooth;
uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int fogMode;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef IS_OPTIFINE
    uniform float eyeHumidity;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"
#include "/lib/world/scattering.glsl"

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/basic_handlight.glsl"
#endif

#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    #include "/lib/sampling/bayer.glsl"
    
    #if SHADOW_PCF_SAMPLES == 12
        #include "/lib/sampling/poisson_12.glsl"
    #elif SHADOW_PCF_SAMPLES == 24
        #include "/lib/sampling/poisson_24.glsl"
    #elif SHADOW_PCF_SAMPLES == 36
        #include "/lib/sampling/poisson_36.glsl"
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #else
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif

    #if defined VL_ENABLED && defined VL_PARTICLES
        #include "/lib/lighting/volumetric.glsl"
    #endif
#endif

#include "/lib/world/sky.glsl"
#include "/lib/world/fog.glsl"
#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/basic_forward.glsl"

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;


void main() {
    vec4 color = BasicLighting();
    color.a *= WEATHER_OPACITY * 0.01;

    vec4 outLuminance = vec4(0.0);
    outLuminance.r = log2(luminance(color.rgb) * color.a + EPSILON);
    outLuminance.a = color.a;
    outColor1 = outLuminance;

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = color;
}
