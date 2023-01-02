#define RENDER_SHADOW
#define RENDER_GBUFFER
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec3 vLocalPos;
out vec2 vTexcoord;
out vec2 vLmcoord;
out vec4 vColor;
flat out int vBlockId;
flat out int vEntityId;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out vec3 vOriginPos;
#endif

#ifdef SSS_ENABLED
    flat out float vMaterialSSS;
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    out vec3 vViewPos;
#endif

#if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
    flat out mat3 vMatShadowViewTBN;
#endif

#ifdef RSM_ENABLED
    flat out mat3 vMatViewTBN;
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    flat out int vWaterMask;
#endif

attribute vec3 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec3 at_midBlock;
attribute vec4 at_tangent;

#if MC_VERSION >= 11700
    attribute vec3 vaPosition;
#endif

uniform sampler2D gtexture;

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

#if MC_VERSION >= 11700 && SHADER_PLATFORM != PLATFORM_IRIS
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

#ifdef PHYSICS_OCEAN
    #include "/lib/physicsMod/water.glsl"
#endif

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && defined SSS_ENABLED
    #include "/lib/material/default.glsl"
#endif


void main() {
    //int blockId = int(mc_Entity.x + 0.5);

    if (renderStage == MC_RENDER_STAGE_ENTITIES) {
        vBlockId = -1;
        vEntityId = entityId;

        // #ifdef SHADOW_EXCLUDE_ENTITIES
        //     if (mc_Entity.x == 0.0) {
        //         gl_Position = vec4(10.0);

        //         #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //             shadowCascadePos = vec2(10.0);
        //         #endif

        //         return;
        //     }
        // #endif

        if (entityId == MATERIAL_LIGHTNING_BOLT) {
            gl_Position = vec4(10.0);
            return;
        }
    }
    else {
        vBlockId = int(mc_Entity.x + 0.5);
        vEntityId = -1;

        #ifdef SHADOW_EXCLUDE_FOLIAGE
            if (vBlockId >= 10000 && vBlockId <= 10004) {
                gl_Position = vec4(10.0);
                return;
            }
        #endif
    }

    vLocalPos = gl_Vertex.xyz;
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;

    vec3 normal = gl_Normal;
    vec3 shadowViewNormal = normalize(gl_NormalMatrix * normal);

    #if defined ENABLE_WAVING || WATER_WAVE_TYPE == WATER_WAVE_VERTEX
        float skyLight = saturate((vLmcoord.y - (0.5/16.0)) / (15.0/16.0));
    #endif

    #ifdef ENABLE_WAVING
        if (vBlockId >= 10001 && vBlockId <= 10004) {
            float wavingRange = GetWavingRange(skyLight);
            vLocalPos += GetWavingOffset(wavingRange);
        }
    #endif

    #ifdef WATER_FANCY
        vWaterMask = 0;
    #endif

    if (vBlockId == MATERIAL_WATER) {
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

        vec3 worldPos = vLocalPos + cameraPosition;

        #ifdef PHYSICS_OCEAN
            #ifdef WATER_FANCY
                vWaterMask = 1;
            #endif
        
            physics_vLocalPosition = vLocalPos;
            float waviness = textureLod(physics_waviness, vLocalPos.xz / vec2(textureSize(physics_waviness, 0)), 0).r;
            float depth = physics_waveHeight(vLocalPos, PHYSICS_ITERATIONS_OFFSET, waviness, physics_gameTime);
            vLocalPos.y += depth;

            #ifndef WATER_FANCY
                vec3 waterWorldPosX = worldPos + vec3(1.0, 0.0, 0.0);
                float depthX = physics_waveHeight(waterWorldPosX, PHYSICS_ITERATIONS_OFFSET, waviness, physics_gameTime);
                vec3 pX = vec3(1.0, 0.0, depthX - depth);

                vec3 waterWorldPosY = worldPos + vec3(0.0, 0.0, 1.0);
                float depthY = physics_waveHeight(waterWorldPosY, PHYSICS_ITERATIONS_OFFSET, waviness, physics_gameTime);
                vec3 pY = vec3(0.0, 1.0, depthY - depth);

                normal = normalize(cross(pX, pY)).xzy;
            #endif
        #else
            #if SHADER_PLATFORM == PLATFORM_IRIS
                // Iris does not cull water backfaces
                if (shadowViewNormal.z <= 0.0) {
                    gl_Position = vec4(10.0);
                    return;
                }
            #endif

            if (gl_Normal.y > 0.5) {
                #ifdef WATER_FANCY
                    vWaterMask = 1;
                #endif
                
                #if WATER_WAVE_TYPE == WATER_WAVE_VERTEX
                    //float windSpeed = GetWindSpeed();
                    //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                    float waveDepth = GetWaveDepth(skyLight);
                    
                    float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                    vec2 waterWorldPos = waterWorldScale * worldPos.xz;
                    float depth = GetWaves(waterWorldPos, waveDepth, WATER_OCTAVES_VERTEX);
                    vLocalPos.y -= (1.0 - depth) * waveDepth;

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
        #endif
    }

    vec4 shadowViewPos = gl_ModelViewMatrix * vec4(vLocalPos, 1.0);

    #if defined WATER_FANCY && defined VL_WATER_ENABLED
        vViewPos = (gbufferModelView * vec4(vLocalPos, 1.0)).xyz;
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #if MC_VERSION >= 11700 && defined IS_OPTIFINE
            vOriginPos = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));
        #else
            vOriginPos = floor(gl_Vertex.xyz + at_midBlock / 64.0 + fract(cameraPosition));
        #endif

        vOriginPos = (gl_ModelViewMatrix * vec4(vOriginPos, 1.0)).xyz;
    #endif

    #if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
        vec3 shadowViewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
        vec3 shadowViewBinormal = normalize(cross(shadowViewTangent, shadowViewNormal) * at_tangent.w);

        vMatShadowViewTBN = mat3(shadowViewTangent, shadowViewBinormal, shadowViewNormal);
    #endif

    #ifdef RSM_ENABLED
        vMatViewTBN = mat3(gbufferModelView) * mat3(shadowModelViewInverse) * vMatShadowViewTBN;
    #endif

    #if defined SSS_ENABLED //|| defined RSM_ENABLED
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            float matF0, matSmooth, matEmissive;
            ApplyHardCodedMaterials(matF0, vMaterialSSS, matSmooth, matEmissive);
        #endif

        // PhysicsMod snow
        if (entityId == 829925) {
            vBlockId = MATERIAL_PHYSICS_SNOW;
            vMaterialSSS = 0.8;
        }
    #endif

    gl_Position = shadowViewPos;
}
