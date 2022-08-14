#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SHADOW

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
//out vec3 localPos;

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && defined SSS_ENABLED
    flat out float matSmooth;
    flat out float matSSS;
    flat out float matF0;
    flat out float matEmissive;
#endif

#ifdef SSS_ENABLED
    out vec3 viewPosTan;
#endif

#if defined RSM_ENABLED
    flat out mat3 matViewTBN;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out float cascadeSizes[4];
    flat out vec2 shadowCascadePos;
#endif

in vec4 mc_Entity;
in vec3 vaPosition;
in vec3 at_midBlock;
in vec4 at_tangent;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform float far;

#ifdef ANIM_USE_WORLDTIME
    uniform int worldTime;
#endif

#if MC_VERSION >= 11700 && (defined IS_OPTIFINE || defined IRIS_FEATURE_CHUNK_OFFSET)
    uniform vec3 chunkOffset;
#else
    uniform mat4 gbufferModelViewInverse;
#endif

#include "/lib/world/wind.glsl"
#include "/lib/world/waving.glsl"

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    uniform int entityId;
    uniform float near;

    #ifdef IS_OPTIFINE
        // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;
    #else
        uniform mat4 gbufferModelView;
        uniform mat4 gbufferProjection;
    #endif

    #include "/lib/shadows/csm.glsl"
#elif SHADOW_TYPE != SHADOW_TYPE_NONE
    #include "/lib/shadows/basic.glsl"
#endif

#if WATER_WAVE_TYPE == WATER_WAVE_VERTEX
    #include "/lib/world/water.glsl"
#endif

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && defined SSS_ENABLED
    #include "/lib/material/default.glsl"
#endif


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    #ifdef SHADOW_EXCLUDE_ENTITIES
        if (mc_Entity.x == 0.0) {
            gl_Position = vec4(10.0);

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                shadowCascadePos = vec2(10.0);
            #endif

            return;
        }
    #endif

    #ifdef SHADOW_EXCLUDE_FOLIAGE
        if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) {
            gl_Position = vec4(10.0);

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                shadowCascadePos = vec2(10.0);
            #endif

            return;
        }
        //else {
    #endif

    vec4 pos = gl_Vertex;
    vec3 normal = gl_Normal;

    #if defined ENABLE_WAVING || WATER_WAVE_TYPE == WATER_WAVE_VERTEX
        float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
    #endif

    #ifdef ENABLE_WAVING
        if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0) {
            float wavingRange = GetWavingRange(skyLight);
            pos.xyz += GetWavingOffset(wavingRange);
        }
    #endif

    #if WATER_WAVE_TYPE == WATER_WAVE_VERTEX
        if (mc_Entity.x == 100.0) {
            float windSpeed = GetWindSpeed();
            float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
            
            float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
            vec2 waterWorldPos = waterWorldScale * (pos.xz + cameraPosition.xz);
            float depth = GetWaves(waterWorldPos, waveSpeed, WATER_OCTAVES_VERTEX);
            pos.y -= (1.0 - depth) * WATER_WAVE_DEPTH;

            #ifndef WATER_FANCY
                vec2 waterWorldPosX = waterWorldPos + vec2(waterWorldScale, 0.0);
                float depthX = GetWaves(waterWorldPosX, waveSpeed, WATER_OCTAVES_VERTEX);
                vec3 pX = vec3(1.0, 0.0, (depthX - depth) * WATER_WAVE_DEPTH);

                vec2 waterWorldPosY = waterWorldPos + vec2(0.0, waterWorldScale);
                float depthY = GetWaves(waterWorldPosY, waveSpeed, WATER_OCTAVES_VERTEX);
                vec3 pY = vec3(0.0, 1.0, (depthY - depth) * WATER_WAVE_DEPTH);

                normal = normalize(cross(pX, pY)).xzy;
            #endif
        }
    #endif

    //vec4 viewPos = shadowModelView * pos;
    vec4 viewPos = gl_ModelViewMatrix * pos;

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        cascadeSizes[0] = GetCascadeDistance(0);
        cascadeSizes[1] = GetCascadeDistance(1);
        cascadeSizes[2] = GetCascadeDistance(2);
        cascadeSizes[3] = GetCascadeDistance(3);

        mat4 matShadowProjections[4];
        matShadowProjections[0] = GetShadowCascadeProjectionMatrix(0);
        matShadowProjections[1] = GetShadowCascadeProjectionMatrix(1);
        matShadowProjections[2] = GetShadowCascadeProjectionMatrix(2);
        matShadowProjections[3] = GetShadowCascadeProjectionMatrix(3);

        int shadowCascade = GetShadowCascade(matShadowProjections);
        shadowCascadePos = GetShadowCascadeClipPos(shadowCascade);
        gl_Position = matShadowProjections[shadowCascade] * viewPos;

        gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
        gl_Position.xy = gl_Position.xy * 0.5 + shadowCascadePos;
        gl_Position.xy = gl_Position.xy * 2.0 - 1.0;
    #else
        gl_Position = gl_ProjectionMatrix * viewPos;

        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            gl_Position.xyz = distort(gl_Position.xyz);
        #endif
    #endif

    // #ifdef SHADOW_EXCLUDE_FOLIAGE
    //     }
    // #endif

    #if defined SSS_ENABLED || defined RSM_ENABLED
        vec3 viewNormal = normalize(gl_NormalMatrix * normal);
        vec3 viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
        vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * at_tangent.w);

        #if !defined RSM_ENABLED //&& DEBUG_VIEW != 2
            mat3 matViewTBN;
        #endif

        matViewTBN = mat3(viewTangent, viewBinormal, viewNormal);

        #ifdef SSS_ENABLED
            viewPosTan = viewPos.xyz * matViewTBN;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            ApplyHardCodedMaterials();
        #endif
    #endif
}
