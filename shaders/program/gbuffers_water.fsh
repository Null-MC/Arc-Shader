#define RENDER_WATER
#define RENDER_GBUFFER
#define RENDER_FRAG

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

    #ifdef WORLD_MOON_ENABLED
        flat in vec3 moonColor;
    #endif

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
        uniform sampler3D texMultipleScattering;
    #else
        uniform sampler3D colortex12;
        uniform sampler3D colortex13;
    #endif

    uniform float eyeAltitude;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform float wetness;
    uniform int moonPhase;
    uniform vec3 skyColor;

    #ifdef SHADOW_ENABLED
        uniform mat4 shadowModelView;
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

            // #if (defined RSM_ENABLED && defined RSM_UPSCALE) || (defined SSS_ENABLED && defined SHADOW_COLOR)
            //     uniform usampler2D shadowcolor1;
            // #endif
        #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            in vec3 shadowPos[4];
            in float shadowBias[4];
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            in vec3 shadowPos;
            in float shadowBias;
        #endif
        
        #if defined VL_SKY_ENABLED || defined VL_WATER_ENABLED
            #if SHADER_PLATFORM == PLATFORM_IRIS
                uniform sampler3D texCloudNoise;
            #else
                uniform sampler3D colortex14;
            #endif
            
            //uniform mat4 gbufferModelView;
            //uniform mat4 gbufferProjection;
        #endif
    #endif
#endif

#ifdef AF_ENABLED
    in vec4 spriteBounds;
#endif

#ifdef HANDLIGHT_ENABLED
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
    
    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform bool firstPersonCamera;
        uniform vec3 eyePosition;
    #endif
#endif

#if AO_TYPE == AO_TYPE_SS
    uniform sampler2D BUFFER_AO;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform usampler2D BUFFER_DEFERRED;

#if SHADER_PLATFORM == PLATFORM_IRIS
    uniform sampler2D texBRDF;
#else
    uniform sampler2D colortex15;
#endif

uniform sampler2D BUFFER_SKY_LUT;
uniform sampler2D BUFFER_IRRADIANCE;

uniform int worldTime;
uniform float frameTimeCounter;
uniform ivec2 atlasSize;

uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform int isEyeInWater;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogMode;
uniform int fogShape;

#if defined SHADOW_CONTACT || REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform mat4 gbufferProjectionInverse;
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    uniform sampler2D BUFFER_DEPTH_PREV;

    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
    //uniform mat4 gbufferProjection;
    uniform vec3 previousCameraPosition;
#endif

#if defined WATER_FANCY || WATER_REFRACTION != WATER_REFRACTION_NONE
    uniform sampler2D BUFFER_HDR_OPAQUE;
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;
uniform float skyWetnessSmooth;
uniform float skySnowSmooth;
uniform float biomeWetnessSmooth;
uniform float biomeSnowSmooth;
uniform vec3 waterScatterColor;
uniform vec3 waterAbsorbColor;
uniform float waterFogDistSmooth;

#include "/lib/atlas.glsl"
#include "/lib/depth.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/sampling/erp.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/fresnel.glsl"
#include "/lib/lighting/brdf.glsl"

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    #include "/lib/material/default.glsl"
#endif

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#if defined WATER_FANCY && defined WORLD_WATER_ENABLED
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"

    #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
        #include "/lib/water_parallax.glsl"
    #endif
#endif

#ifdef PHYSICS_OCEAN
    #include "/lib/physicsMod/water.glsl"
#endif

#if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
    #include "/lib/lighting/directional.glsl"
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/scattering.glsl"

    #include "/lib/sky/hillaire_render.glsl"
    #include "/lib/sky/clouds.glsl"
    #include "/lib/sky/stars.glsl"
#endif

#include "/lib/world/weather.glsl"
#include "/lib/world/fog_vanilla.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire.glsl"
    #include "/lib/world/fog_fancy.glsl"
    #include "/lib/lighting/basic.glsl"

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #else
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
    #include "/lib/lighting/handlight_common.glsl"
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"
#include "/lib/lighting/pbr_forward.glsl"

/* RENDERTARGETS: 2,1 */
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
