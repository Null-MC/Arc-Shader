#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_HAND_WATER

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 viewPos;
in vec3 viewNormal;
in vec3 viewTangent;
in vec3 localPos;
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

#if defined PARALLAX_ENABLED || WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
    in vec2 localCoord;
    in vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        in vec3 tanLightPos;
    #endif
#endif

#ifdef SKY_ENABLED
    flat in vec2 skyLightLevels;
    flat in vec3 sunColor;
    flat in vec3 moonColor;

    uniform sampler3D colortex9;
    
    uniform mat4 gbufferModelView;

    uniform float eyeAltitude;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform vec3 skyColor;
    uniform float wetness;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        flat in vec3 skyLightColor;

        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform mat4 shadowModelViewInverse;
        uniform vec3 shadowLightPosition;

        #if SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform sampler2D shadowtex0;
            uniform sampler2D shadowtex1;
            uniform usampler2D shadowcolor1;
        
            #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
                uniform sampler2DShadow shadowtex1HW;
            #endif

            #if defined SHADOW_COLOR || defined SSS_ENABLED
                uniform sampler2D shadowcolor0;
            #endif

            //#if (defined RSM_ENABLED && defined RSM_UPSCALE) || (defined SSS_ENABLED && defined SHADOW_COLOR)
            //    uniform usampler2D shadowcolor1;
            //#endif
        #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            flat in vec3 matShadowProjections_scale[4];
            flat in vec3 matShadowProjections_translation[4];
            flat in float cascadeSizes[4];
            out vec3 shadowPos[4];
            out float shadowBias[4];
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            in vec4 shadowPos;
            in float shadowBias;
        #endif
        
        #if defined VL_SKY_ENABLED || defined VL_WATER_ENABLED
            uniform sampler3D colortex13;
            
            //uniform mat4 gbufferProjection;
        #endif
    #endif
#endif

#ifdef AF_ENABLED
    in vec4 spriteBounds;
#endif

#if AO_TYPE == AO_TYPE_SS
    uniform sampler2D BUFFER_AO;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;
uniform sampler2D noisetex;
uniform sampler2D colortex10;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#if ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
    uniform sampler2D BUFFER_SKY_LUT;
#endif

uniform ivec2 atlasSize;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;

uniform float frameTimeCounter;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;
uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogMode;
uniform int fogShape;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;
uniform vec3 waterScatterColor;
uniform vec3 waterAbsorbColor;
uniform float waterFogDistSmooth;

#if defined SHADOW_CONTACT || REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform mat4 gbufferProjectionInverse;
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    uniform sampler2D BUFFER_DEPTH_PREV;

    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
    uniform vec3 previousCameraPosition;
#endif

#include "/lib/atlas.glsl"
#include "/lib/depth.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/fresnel.glsl"
#include "/lib/lighting/brdf.glsl"

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
    #include "/lib/lighting/directional.glsl"
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/sun_moon.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/scattering.glsl"
#endif

#include "/lib/world/weather.glsl"
#include "/lib/world/fog.glsl"

#ifdef SKY_ENABLED
    #if ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
        #include "/lib/sky/hillaire_common.glsl"
        #include "/lib/sky/hillaire_render.glsl"
    #endif

    #include "/lib/sky/clouds.glsl"
    #include "/lib/sky/stars.glsl"
    
    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif

        #if defined VL_SKY_ENABLED || defined VL_WATER_ENABLED
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif

    #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
        #include "/lib/shadows/contact.glsl"
    #endif
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    #include "/lib/ssr.glsl"
#endif

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"
#include "/lib/lighting/pbr_forward.glsl"

/* RENDERTARGETS: 4,6 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;


void main() {
    vec4 color = PbrLighting();

    vec4 outLum = vec4(0.0);
    outLum.r = log2(luminance(color.rgb) + EPSILON);
    outLum.a = color.a;
    outColor1 = outLum;

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = color;
}
