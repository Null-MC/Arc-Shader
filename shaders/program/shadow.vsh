#define RENDER_SHADOW
#define RENDER_GBUFFER
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec3 vLocalPos;
out vec2 vTexcoord;
out vec4 vColor;
out float vNoV;
flat out int vBlockId;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out vec3 vOriginPos;
#endif

out vec3 vViewPos;

attribute vec3 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec3 at_midBlock;
attribute vec4 at_tangent;

#if MC_VERSION >= 11700
    attribute vec3 vaPosition;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform int entityId;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform int renderStage;
uniform int worldTime;
uniform float far;

#if MC_VERSION >= 11700 && SHADER_PLATFORM != PLATFORM_IRIS
    uniform vec3 chunkOffset;
#else
    uniform mat4 gbufferModelViewInverse;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    uniform float near;

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;
    #else
        //uniform mat4 gbufferModelView;
        uniform mat4 gbufferProjection;
    #endif
#endif

#include "/lib/matrix.glsl"
#include "/lib/world/wind.glsl"
#include "/lib/world/waving.glsl"
#include "/lib/celestial/position.glsl"
#include "/lib/shadows/common.glsl"

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
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


void main() {
    vBlockId = -1;
    if (renderStage != MC_RENDER_STAGE_ENTITIES)
        vBlockId = int(mc_Entity.x + 0.5);

    vLocalPos = gl_Vertex.xyz;
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec2 lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;

    #ifndef IRIS_FEATURE_SSBO
        mat4 shadowModelViewEx = BuildShadowViewMatrix();
    #endif

    vec3 shadowViewNormal = normalize(mat3(shadowModelViewEx) * gl_Normal);
    vNoV = shadowViewNormal.z;

    #if defined ENABLE_WAVING || WATER_WAVE_TYPE == WATER_WAVE_VERTEX
        float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
    #endif

    #ifdef ENABLE_WAVING
        if (vBlockId >= 10001 && vBlockId <= 10004) {
            float wavingRange = GetWavingRange(skyLight);
            vLocalPos += GetWavingOffset(wavingRange);
        }
    #endif

    if (vBlockId == MATERIAL_WATER) {
        #ifdef PHYSICS_OCEAN
            physics_vLocalWaviness = physics_GetWaviness(ivec2(vLocalPos.xz));
            float depth = physics_waveHeight(vLocalPos, PHYSICS_ITERATIONS_OFFSET, physics_vLocalWaviness, physics_gameTime);
            vLocalPos.y += depth;
            physics_vLocalPosition = vLocalPos;
        #else
            if (gl_Normal.y > 0.5) {
                #if WATER_WAVE_TYPE == WATER_WAVE_VERTEX
                    vec3 worldPos = vLocalPos + cameraPosition;
                
                    //float windSpeed = GetWindSpeed();
                    //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                    float waveDepth = GetWaveDepth(skyLight);
                    
                    float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                    vec2 waterWorldPos = waterWorldScale * worldPos.xz;
                    vec3 waves = GetWaves(waterWorldPos, waveDepth, WATER_OCTAVES_VERTEX);
                    vLocalPos.y -= (1.0 - waves.y) * waveDepth;
                #endif
            }
        #endif
    }

    gl_Position = gl_ModelViewMatrix * vec4(vLocalPos, 1.0);
    vec3 shadowLocalPos = (shadowModelViewInverse * gl_Position).xyz;
    gl_Position = shadowModelViewEx * vec4(shadowLocalPos, 1.0);

    vViewPos = (gbufferModelView * vec4(shadowLocalPos, 1.0)).xyz;
    
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //vOriginPos = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));
        vOriginPos = floor(gl_Vertex.xyz + at_midBlock / 64.0 + fract(cameraPosition));

        vOriginPos = (gl_ModelViewMatrix * vec4(vOriginPos, 1.0)).xyz;
        vOriginPos = (shadowModelViewInverse * vec4(vOriginPos, 1.0)).xyz;
        vOriginPos = (shadowModelViewEx * vec4(vOriginPos, 1.0)).xyz;
    #endif
}
