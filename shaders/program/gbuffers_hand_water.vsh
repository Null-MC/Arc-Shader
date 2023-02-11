#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_HAND_WATER

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 viewPos;
out vec3 viewNormal;
out vec3 viewTangent;
out vec3 localPos;
flat out float tangentW;
flat out int materialId;
flat out mat2 atlasBounds;

#ifndef IRIS_FEATURE_SSBO
    flat out float sceneExposure;

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

    flat out vec3 blockLightColor;

    #ifdef SKY_ENABLED
        flat out vec2 skyLightLevels;

        flat out vec3 skySunColor;

        #ifdef WORLD_MOON_ENABLED
            flat out vec3 skyMoonColor;
        #endif
    #endif
#endif

#if defined PARALLAX_ENABLED
    out vec2 localCoord;
    out vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        out vec3 tanLightPos;
    #endif
#endif

#ifdef SKY_ENABLED
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform int moonPhase;
    uniform float wetness;

    #if defined SHADOW_ENABLED
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform vec3 shadowLightPosition;
        uniform float far;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            out vec3 shadowPos[4];
            out float shadowBias[4];

            #ifndef IS_IRIS
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

            uniform mat4 gbufferProjection;
            uniform float near;
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            out vec3 shadowPos;
            out float shadowBias;
        #endif
    #endif
#endif

#ifdef AF_ENABLED
    out vec4 spriteBounds;
#endif

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec3 at_midBlock;

#if MC_VERSION >= 11700
    attribute vec3 vaPosition;
#endif

#if defined PARALLAX_ENABLED || defined AF_ENABLED
    attribute vec4 mc_midTexCoord;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float screenBrightness;
uniform vec3 cameraPosition;
uniform int worldTime;

uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11700 && !defined IS_IRIS
    uniform vec3 chunkOffset;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#include "/lib/matrix.glsl"
#include "/lib/lighting/blackbody.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/common.glsl"

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
        #else
            #include "/lib/shadows/basic.glsl"
        #endif
    #endif
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"

#ifndef IRIS_FEATURE_SSBO
    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    //if (mc_Entity.x == 100.0) materialId = 1;
    //else materialId = 0;
    materialId = -1;

    localPos = gl_Vertex.xyz;
    BasicVertex(localPos);
    PbrVertex(viewPos);

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 viewDir = normalize(viewPos);
        ApplyShadows(localPos, viewDir);
    #endif
    
    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #ifndef IRIS_FEATURE_SSBO
            mat4 shadowModelViewEx = BuildShadowViewMatrix();
        #endif

        vec3 shadowViewPos = (shadowModelViewEx * vec4(localPos, 1.0)).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                shadowPos[i] = (cascadeProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowProjectionPos[i];
                
                shadowBias[i] = GetCascadeBias(geoNoL, shadowProjectionSize[i]);
            }
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            #ifndef IRIS_FEATURE_SSBO
                mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
            #endif
        
            shadowPos = (shadowProjectionEx * vec4(shadowViewPos, 1.0)).xyz;

            float distortFactor = getDistortFactor(shadowPos.xy);
            //shadowPos = distort(shadowPos, distortFactor) * 0.5 + 0.5;
            shadowPos = shadowPos * 0.5 + 0.5;
            shadowBias = GetShadowBias(geoNoL, distortFactor);
        #endif
    #endif

    #ifndef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();

        blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

        #ifdef SKY_ENABLED
            skyLightLevels = GetSkyLightLevels();

            skySunColor = GetSunColor();

            #ifdef WORLD_MOON_ENABLED
                skyMoonColor = GetMoonColor();
            #endif
        #endif
    #endif
}
