#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_WATER

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 viewPos;
in vec3 localPos;
in vec3 viewNormal;
in vec3 viewTangent;
flat in float tangentW;
flat in float exposure;
flat in int materialId;
flat in vec3 blockLightColor;
flat in mat2 atlasBounds;

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    flat in float matSmooth;
    flat in float matF0;
    flat in float matSSS;
    flat in float matEmissive;
#endif

#ifdef PARALLAX_ENABLED
    in vec2 localCoord;
    in vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        in vec3 tanLightPos;
    #endif
#endif

#ifdef SKY_ENABLED
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in vec3 skyLightColor;

    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform float wetness;
    uniform int moonPhase;
    uniform vec3 skyColor;

    #ifdef SHADOW_ENABLED
        uniform mat4 shadowModelView;
        uniform vec3 shadowLightPosition;

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
        #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            flat in float cascadeSizes[4];
            flat in vec3 matShadowProjections_scale[4];
            flat in vec3 matShadowProjections_translation[4];
        #endif
    #endif
#endif

#ifdef AF_ENABLED
    in vec4 spriteBounds;
#endif

#ifdef HANDLIGHT_ENABLED
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#if AO_TYPE == AO_TYPE_FANCY
    uniform sampler2D BUFFER_AO;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D colortex10;

uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform ivec2 atlasSize;
uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogMode;
uniform int fogShape;

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    uniform sampler2D BUFFER_DEPTH_PREV;

    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
    uniform mat4 gbufferProjectionInverse;
    //uniform mat4 gbufferProjection;
    uniform vec3 previousCameraPosition;
#endif

#if defined WATER_FANCY || WATER_REFRACTION != WATER_REFRACTION_NONE
    uniform sampler2D BUFFER_REFRACT;
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    uniform sampler2D BUFFER_WATER_WAVES;

    uniform float frameTimeCounter;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef IS_OPTIFINE
    uniform float eyeHumidity;
#endif

#include "/lib/atlas.glsl"
#include "/lib/depth.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"

    #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
        #include "/lib/water_parallax.glsl"
    #endif
#endif

#if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
    #include "/lib/lighting/directional.glsl"
#endif

#ifdef SKY_ENABLED
    #include "/lib/world/scattering.glsl"
    #include "/lib/world/porosity.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/lighting/basic.glsl"

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

        #ifdef SHADOW_CONTACT
            #include "/lib/shadows/contact.glsl"
        #endif

        #ifdef VL_ENABLED
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif
#endif

#include "/lib/world/fog.glsl"
#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    #include "/lib/ssr.glsl"
#endif

#include "/lib/lighting/brdf.glsl"

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"
#include "/lib/lighting/pbr_forward.glsl"

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;


void main() {
    vec4 color = PbrLighting();

    vec4 outLum = vec4(0.0);
    outLum.r = log2(luminance(color.rgb) + EPSILON);
    outLum.a = color.a;
    outColor1 = outLum;

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = color;
}
