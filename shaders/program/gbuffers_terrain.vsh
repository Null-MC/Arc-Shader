#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_TERRAIN

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 viewPos;
out vec3 localPos;
out vec3 viewNormal;
out vec3 viewTangent;
flat out float tangentW;
flat out float exposure;
flat out int materialId;
flat out vec3 blockLightColor;
flat out mat2 atlasBounds;

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    flat out float matSmooth;
    flat out float matF0;
    flat out float matSSS;
    flat out float matEmissive;
#endif

#if defined PARALLAX_ENABLED || WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
    out vec2 localCoord;
    out vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        out vec3 tanLightPos;
    #endif
#endif

#ifdef SKY_ENABLED
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec2 skyLightLevels;

    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform float wetness;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform vec3 shadowLightPosition;
        uniform float far;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            flat out vec3 matShadowProjections_scale[4];
            flat out vec3 matShadowProjections_translation[4];
            flat out float cascadeSizes[4];
            out vec3 shadowPos[4];
            out float shadowBias[4];

            #if SHADER_PLATFORM == PLATFORM_OPTIFINE
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

            uniform mat4 gbufferProjection;
            uniform float near;
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            out vec4 shadowPos;
            out float shadowBias;
        #endif
    #endif
#endif

#ifdef AF_ENABLED
    out vec4 spriteBounds;
#endif

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    
    uniform float viewWidth;
    uniform float viewHeight;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

attribute vec3 mc_Entity;
attribute vec4 at_tangent;
attribute vec3 at_midBlock;
attribute vec4 mc_midTexCoord;

#if MC_VERSION >= 11700
    attribute vec3 vaPosition;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float screenBrightness;
uniform vec3 cameraPosition;

uniform int isEyeInWater;
uniform float nightVision;
uniform float blindness;

#if SHADER_PLATFORM == PLATFORM_OPTIFINE
    uniform int worldTime;
//#else
//    uniform mat4 gbufferModelView;
#endif

#if defined WATER_ENABLED && WATER_WAVE_TYPE == WATER_WAVE_VERTEX
    uniform float frameTimeCounter;
#endif

#if MC_VERSION >= 11700 && (SHADER_PLATFORM != PLATFORM_IRIS || defined IRIS_FEATURE_CHUNK_OFFSET)
    uniform vec3 chunkOffset;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef SHADOW_ENABLED
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
    #endif
#endif

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    #include "/lib/material/default.glsl"
#endif

#include "/lib/lighting/blackbody.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/celestial_position.glsl"
    #include "/lib/sky/celestial_color.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/wind.glsl"
    #include "/lib/world/waving.glsl"
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    //localPos = gl_Vertex.xyz;
    glcolor = gl_Color;

    materialId = int(mc_Entity.x + 0.5);

    // if (mc_Entity.x == 100.0 || mc_Entity.x == 101.0) materialId = 1;
    // // Nether Portal
    // else if (mc_Entity.x == 102.0) materialId = 2;
    // // undefined
    // else materialId = 0;

    vec3 vPos = gl_Vertex.xyz;
    BasicVertex(vPos);
    PbrVertex(viewPos);

    localPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * vec4(vPos, 1.0))).xyz;

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 viewDir = normalize(viewPos);
        ApplyShadows(localPos, viewDir);
    #endif

    #ifdef SKY_ENABLED
        sunColor = GetSunLuxColor();
        moonColor = GetMoonLuxColor();// * GetMoonPhaseLevel();
        skyLightLevels = GetSkyLightLevels();
    #endif

    blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

    exposure = GetExposure();

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos, 1.0))).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                mat4 matShadowProjection = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                shadowPos[i] = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                
                vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;

                vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjection[0].x, matShadowProjection[1].y);;
                shadowBias[i] = GetCascadeBias(geoNoL, shadowProjectionSize);
            }
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
                shadowBias = GetShadowBias(geoNoL, distortFactor);
            #else
                shadowBias = GetShadowBias(geoNoL);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
        #endif
    #endif
}
