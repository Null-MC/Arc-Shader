#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_WATER

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

#ifdef PARALLAX_ENABLED
    out vec2 localCoord;
    out vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        out vec3 tanLightPos;
    #endif
#endif

#ifdef SKY_ENABLED
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec3 skyLightColor;

    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform vec3 shadowLightPosition;
        uniform float far;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            flat out float cascadeSizes[4];
            flat out vec3 matShadowProjections_scale[4];
            flat out vec3 matShadowProjections_translation[4];

            #ifdef IS_OPTIFINE
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

            uniform mat4 gbufferProjection;
            uniform float near;
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

in vec4 mc_Entity;
in vec3 vaPosition;
in vec4 at_tangent;
in vec3 at_midBlock;

#if defined PARALLAX_ENABLED || defined AF_ENABLED
    in vec4 mc_midTexCoord;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float screenBrightness;
uniform vec3 cameraPosition;
uniform float blindness;

#if WATER_WAVE_TYPE == WATER_WAVE_VERTEX && !defined WORLD_NETHER
    uniform float frameTimeCounter;
#endif

#if MC_VERSION >= 11700 && (defined IS_OPTIFINE || defined IRIS_FEATURE_CHUNK_OFFSET)
    uniform vec3 chunkOffset;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef SHADOW_ENABLED
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#if WATER_WAVE_TYPE == WATER_WAVE_VERTEX && !defined WORLD_NETHER
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"
#endif

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    #include "/lib/material/default.glsl"
#endif

#include "/lib/lighting/blackbody.glsl"

#ifdef SKY_ENABLED
    #include "/lib/world/sky.glsl"
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    localPos = gl_Vertex.xyz;
    glcolor = gl_Color;

    // water
    if (mc_Entity.x == 100.0 || mc_Entity.x == 101.0) materialId = 1;
    // Nether Portal
    else if (mc_Entity.x == 102.0) materialId = 2;
    // undefined
    else materialId = 0;

    BasicVertex(localPos);
    PbrVertex(viewPos);

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 viewDir = normalize(viewPos);
        ApplyShadows(localPos, viewDir);
    #endif

    #ifdef SKY_ENABLED
        vec2 skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
        sunColor = GetSunLightLuxColor(skyLightTemps.x, skyLightLevels.x);
        moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);
        skyLightColor = GetSkyLightLuxColor(skyLightLevels);
    #endif

    blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

    exposure = GetExposure();
}
