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
flat in int materialId;
flat in mat2 atlasBounds;

#ifndef IRIS_FEATURE_SSBO
    flat in float sceneExposure;

    flat in vec3 blockLightColor;
    
    #ifdef SKY_ENABLED
        flat in vec2 skyLightLevels;

        flat in vec3 skySunColor;
        vec3 sunTransmittanceEye;

        #ifdef WORLD_MOON_ENABLED
            flat in vec3 skyMoonColor;
            vec3 moonTransmittanceEye;
        #endif
    #endif
#endif

#if defined PARALLAX_ENABLED
    in vec2 localCoord;
    in vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        in vec3 tanLightPos;
    #endif
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        in vec3 shadowPos[4];
        in float shadowBias[4];
    #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
        in vec3 shadowPos;
        in float shadowBias;
    #endif
#endif

#ifdef AF_ENABLED
    in vec4 spriteBounds;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

//uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D BUFFER_HDR_OPAQUE;
uniform sampler2D TEX_BRDF;

#ifdef SKY_ENABLED
    uniform sampler2D BUFFER_SKY_LUT;
    uniform sampler2D BUFFER_IRRADIANCE;
    uniform sampler3D TEX_SUN_TRANSMIT;
    uniform sampler3D TEX_MULTI_SCATTER;
#endif

#if defined SKY_VL_ENABLED || defined WORLD_WATER_ENABLED
    uniform sampler3D TEX_CLOUD_NOISE;
#endif

#ifdef SKY_ENABLED
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
        #endif
    #endif
#endif

#ifdef HANDLIGHT_ENABLED
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
    
    #ifdef IS_IRIS
        uniform bool firstPersonCamera;
        uniform vec3 eyePosition;
    #endif
#endif

// #if AO_TYPE == AO_TYPE_SS
//     uniform sampler2D BUFFER_AO;
// #endif

uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform ivec2 atlasSize;
uniform ivec2 eyeBrightnessSmooth;
uniform float frameTimeCounter;
//uniform ivec2 eyeBrightness;
uniform int isEyeInWater;
uniform int worldTime;

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
    //uniform mat4 gbufferProjection;
    uniform vec3 previousCameraPosition;
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
uniform vec3 waterFoamColor;
uniform float waterFoamMinSmooth;
uniform float waterFoamMaxSmooth;
uniform float waterFogDistSmooth;
uniform float waterRoughSmooth;

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/scene.glsl"
    #include "/lib/ssbo/vogel_disk.glsl"
#endif

#include "/lib/atlas.glsl"
#include "/lib/blocks.glsl"
#include "/lib/depth.glsl"
#include "/lib/matrix.glsl"
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
    #ifdef RENDER_ENTITIES
        #include "/lib/material/entity_default.glsl"
    #else
        #include "/lib/material/default.glsl"
    #endif
#endif

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#ifdef WORLD_WATER_ENABLED
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"
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
#endif

#include "/lib/world/weather.glsl"
#include "/lib/world/fog_vanilla.glsl"
#include "/lib/world/scattering.glsl"

#ifdef WORLD_WATER_ENABLED
    #include "/lib/world/caustics.glsl"
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire.glsl"
    #include "/lib/sky/hillaire_render.glsl"
    #include "/lib/world/fog_fancy.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/sky/clouds.glsl"
    #include "/lib/sky/stars.glsl"

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/sampling/ign.glsl"
        #include "/lib/shadows/common.glsl"
    
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #else
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif

        #if defined SKY_VL_ENABLED || defined WATER_VL_ENABLED
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif

    // #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
    //     #include "/lib/shadows/contact.glsl"
    // #endif
#endif

#ifdef IRIS_FEATURE_SSBO
    #ifdef LIGHT_COLOR_ENABLED
        #include "/lib/ssbo/lighting.glsl"
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
    #if !defined IRIS_FEATURE_SSBO && defined SKY_ENABLED
        float eyeElevation = GetScaledSkyHeight(eyeAltitude);

        sunTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.x);

        #ifdef WORLD_MOON_ENABLED
            moonTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.y);
        #endif
    #endif
    
    vec4 color = PbrLighting();

    vec4 outLum = vec4(0.0);
    outLum.r = log2(luminance(color.rgb) + EPSILON);
    outLum.a = color.a;
    outColor1 = outLum;

    color.rgb = clamp(color.rgb * sceneExposure, vec3(0.0), vec3(65000));

    outColor0 = color;
}
