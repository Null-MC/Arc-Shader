#define RENDER_SHADOW
#define RENDER_GBUFFER
#define RENDER_GEOMETRY

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices=12) out;

in vec3 vLocalPos[3];
in vec2 vTexcoord[3];
in vec2 vLmcoord[3];
in vec4 vColor[3];
in float vNoV[3];
flat in int vBlockId[3];
//flat in int vEntityId[3];

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat in vec3 vOriginPos[3];
#endif

// #ifdef SSS_ENABLED
//     flat in float vMaterialSSS[3];
// #endif

#if defined RSM_ENABLED || defined WATER_FANCY
    in vec3 vViewPos[3];
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    in mat3 vMatShadowViewTBN[3];
#endif

#ifdef RSM_ENABLED
    flat in mat3 vMatViewTBN[3];
#endif

// #if defined WATER_ENABLED && defined WATER_FANCY
//     flat in int vWaterMask[3];
// #endif

out vec3 gLocalPos;
out vec2 gTexcoord;
out vec2 gLmcoord;
out vec4 gColor;
flat out int gBlockId;
//flat out int gEntityId;

// #ifdef SSS_ENABLED
//     flat out float gMaterialSSS;
// #endif

#if defined RSM_ENABLED || defined WATER_FANCY
    out vec3 gViewPos;
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    out mat3 gMatShadowViewTBN;
#endif

#ifdef RSM_ENABLED
    flat out mat3 gMatViewTBN;
#endif

// #if defined WATER_ENABLED && defined WATER_FANCY
//     flat out int gWaterMask;
// #endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out vec2 gShadowTilePos;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;
uniform int renderStage;
uniform int entityId;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    uniform float near;
    uniform float far;

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE
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

#ifdef PHYSICS_OCEAN
    #include "/lib/physicsMod/water.glsl"
#endif


void ApplyCommonProperties(const in int v) {
    gLocalPos = vLocalPos[v];
    gTexcoord = vTexcoord[v];
    gLmcoord = vLmcoord[v];
    gColor = vColor[v];

    gBlockId = vBlockId[v];
    //gEntityId = vEntityId[v];

    // #ifdef SSS_ENABLED
    //     gMaterialSSS = vMaterialSSS[v];
    // #endif

    #if defined RSM_ENABLED || (defined WATER_FANCY)
        gViewPos = vViewPos[v];
    #endif

    #if defined RSM_ENABLED || defined WATER_FANCY
        gMatShadowViewTBN = vMatShadowViewTBN[v];
    #endif

    #ifdef RSM_ENABLED
        gMatViewTBN = vMatViewTBN[v];
    #endif

    // #if defined WATER_ENABLED && defined WATER_FANCY
    //     gWaterMask = vWaterMask[v];
    // #endif

    #ifdef PHYSICS_OCEAN
        physics_gLocalPosition = physics_vLocalPosition[v];
    #endif
}

void main() {
    //int blockId = -1;

    if (renderStage == MC_RENDER_STAGE_ENTITIES) {
        #ifdef SHADOW_EXCLUDE_ENTITIES
            //if (vEntityId[0] == 0) return;
            return;
        #endif

        if (entityId == MATERIAL_LIGHTNING_BOLT) return;
    }

    #ifdef SHADOW_EXCLUDE_FOLIAGE
        if (renderStage == MC_RENDER_STAGE_TERRAIN || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
            //blockId = int(mc_Entity.x + 0.5);
            if (vBlockId[0] >= 10000 && vBlockId[0] <= 10004) return;
        }
    #endif

    #if SHADER_PLATFORM == PLATFORM_IRIS && !defined PHYSICS_OCEAN
        // Iris does not cull water backfaces
        if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT && vBlockId[0] == MATERIAL_WATER) {
            if (vNoV[0] <= 0.0 && vNoV[1] <= 0.0 && vNoV[2] <= 0.0) return;
        }
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        int shadowTile = GetShadowCascade(cascadeProjection, vOriginPos[0]);
        if (shadowTile < 0) return;

        #ifndef SHADOW_EXCLUDE_ENTITIES
            if (renderStage == MC_RENDER_STAGE_ENTITIES && entityId == CSM_PLAYER_ID) shadowTile = 0;
        #endif

        int cascadeMin = max(shadowTile - 1, 0);
        int cascadeMax = min(shadowTile + 1, 3);

        for (int c = cascadeMin; c <= cascadeMax; c++) {
            if (c != shadowTile) {
                // duplicate geometry if intersecting overlapping cascades
                if (!CascadeIntersectsPosition(vOriginPos[0], cascadeProjection[c])) continue;
            }

            for (int v = 0; v < 3; v++) {
                ApplyCommonProperties(v);

                gShadowTilePos = shadowProjectionPos[c];

                gl_Position = cascadeProjection[c] * gl_in[v].gl_Position;

                gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
                gl_Position.xy = gl_Position.xy * 0.5 + shadowProjectionPos[c];
                gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

                EmitVertex();
            }

            EndPrimitive();
        }
    #else
        for (int v = 0; v < 3; v++) {
            ApplyCommonProperties(v);

            gl_Position = gl_ProjectionMatrix * gl_in[v].gl_Position;

            #if SHADOW_TYPE == 2
                gl_Position.xyz = distort(gl_Position.xyz);
            #endif

            EmitVertex();
        }

        EndPrimitive();
    #endif
}
