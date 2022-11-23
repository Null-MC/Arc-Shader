#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SHADOW

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 localPos;
flat out int materialId;

#ifdef SSS_ENABLED
    flat out float matSSS;
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    out vec3 viewPos;
    flat out mat3 matShadowViewTBN;
#endif

#ifdef RSM_ENABLED
    flat out mat3 matViewTBN;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out float cascadeSizes[4];
    flat out vec2 shadowCascadePos;
#endif

//#ifdef PHYSICSMOD_ENABLED
    uniform sampler2D gtexture;
    in vec4 mc_midTexCoord;
//#endif

in vec4 mc_Entity;
in vec3 vaPosition;
in vec3 at_midBlock;
in vec4 at_tangent;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform int entityId;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform int renderStage;
uniform float far;

#ifdef ANIM_USE_WORLDTIME
    uniform int worldTime;
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    flat out int waterMask;
#endif

#if MC_VERSION >= 11700 && (SHADER_PLATFORM != PLATFORM_IRIS || defined IRIS_FEATURE_CHUNK_OFFSET)
    uniform vec3 chunkOffset;
#else
    uniform mat4 gbufferModelViewInverse;
#endif

#include "/lib/world/wind.glsl"
#include "/lib/world/waving.glsl"

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    //uniform int entityId;
    uniform float near;

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;
    #else
        //uniform mat4 gbufferModelView;
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
    if (renderStage == MC_RENDER_STAGE_ENTITIES) {
        if (entityId == MATERIAL_LIGHTNING_BOLT) {
            gl_Position = vec4(10.0);
            return;
        }
    }

    localPos = gl_Vertex.xyz;
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
    #endif

    vec3 normal = gl_Normal;
    vec3 shadowViewNormal = normalize(gl_NormalMatrix * normal);

    #if defined ENABLE_WAVING || WATER_WAVE_TYPE == WATER_WAVE_VERTEX
        float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
    #endif

    #ifdef ENABLE_WAVING
        if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0) {
            float wavingRange = GetWavingRange(skyLight);
            localPos += GetWavingOffset(wavingRange);
        }
    #endif

    materialId = int(mc_Entity.x + 0.5);

    #ifdef WATER_FANCY
        waterMask = 0;
    #endif

    if (materialId == MATERIAL_WATER) {
        // #ifdef WATER_FANCY
        //     waterMask = 1;
        // #endif

        // #if MC_VERSION >= 11700
        //     float vY = -at_midBlock.y / 64.0;
        //     float posY = saturate(vY + 0.5) * (1.0 - step(0.5, vY + EPSILON));
        // #else
        //     float posY = step(EPSILON, gl_Normal.y);
        // #endif

        //vec3 shadowViewNormal = normalize(gl_NormalMatrix * normal);
        //vec3 worldNormal = mat3(shadowModelViewInverse) * shadowViewNormal;

        #if SHADER_PLATFORM == PLATFORM_IRIS
            if (shadowViewNormal.z <= 0.0) {
                gl_Position = vec4(10.0);
                return;
            }
        #endif

        if (gl_Normal.y > 0.5) {
            #ifdef WATER_FANCY
                waterMask = 1;
            #endif
            
            #if WATER_WAVE_TYPE == WATER_WAVE_VERTEX
                //float windSpeed = GetWindSpeed();
                //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                float waveDepth = GetWaveDepth(skyLight);
                
                float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                vec2 waterWorldPos = waterWorldScale * (localPos.xz + cameraPosition.xz);
                float depth = GetWaves(waterWorldPos, waveDepth, WATER_OCTAVES_VERTEX);
                localPos.y -= (1.0 - depth) * waveDepth;

                #ifndef WATER_FANCY
                    vec2 waterWorldPosX = waterWorldPos + vec2(waterWorldScale, 0.0);
                    float depthX = GetWaves(waterWorldPosX, waveDepth, WATER_OCTAVES_VERTEX);
                    vec3 pX = vec3(1.0, 0.0, (depthX - depth) * waveDepth);

                    vec2 waterWorldPosY = waterWorldPos + vec2(0.0, waterWorldScale);
                    float depthY = GetWaves(waterWorldPosY, waveDepth, WATER_OCTAVES_VERTEX);
                    vec3 pY = vec3(0.0, 1.0, (depthY - depth) * waveDepth);

                    normal = normalize(cross(pX, pY)).xzy;
                #endif
            #endif
        }
    }

    vec4 shadowViewPos = gl_ModelViewMatrix * vec4(localPos, 1.0);

    #if defined WATER_FANCY && defined VL_WATER_ENABLED
        viewPos = (gbufferModelView * vec4(localPos, 1.0)).xyz;
    #endif

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
        gl_Position = matShadowProjections[shadowCascade] * shadowViewPos;

        gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
        gl_Position.xy = gl_Position.xy * 0.5 + shadowCascadePos;
        gl_Position.xy = gl_Position.xy * 2.0 - 1.0;
    #else
        gl_Position = gl_ProjectionMatrix * shadowViewPos;

        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            gl_Position.xyz = distort(gl_Position.xyz);
        #endif
    #endif

    #if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
        //vec3 shadowViewNormal = normalize(gl_NormalMatrix * normal);
        vec3 shadowViewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
        vec3 shadowViewBinormal = normalize(cross(shadowViewTangent, shadowViewNormal) * at_tangent.w);

        matShadowViewTBN = mat3(shadowViewTangent, shadowViewBinormal, shadowViewNormal);
    #endif

    #ifdef RSM_ENABLED
        matViewTBN = mat3(gbufferModelView) * mat3(shadowModelViewInverse) * matShadowViewTBN;
    #endif

    #if defined SSS_ENABLED || defined RSM_ENABLED
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            float matF0, matSmooth, matEmissive;
            ApplyHardCodedMaterials(matF0, matSSS, matSmooth, matEmissive);
        #endif

        // PhysicsMod snow
        if (entityId == 829925) {
            materialId = MATERIAL_PHYSICS_SNOW;
            matSSS = 0.8;
        }
    #endif
}
