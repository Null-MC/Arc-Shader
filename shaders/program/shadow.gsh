#define RENDER_SHADOW
#define RENDER_GBUFFER
#define RENDER_GEOMETRY

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices=12) out;

in vec3 vLocalPos[3];
in vec2 vTexcoord[3];
in vec4 vColor[3];
in float vNoV[3];
flat in int vBlockId[3];
flat in vec3 vOriginPos[3];

in vec3 vViewPos[3];

out vec3 gLocalPos;
out vec2 gTexcoord;
out vec4 gColor;
flat out int gBlockId;

out vec3 gViewPos;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat out vec2 gShadowTilePos;
#endif

uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;
uniform int renderStage;
uniform int worldTime;
uniform int entityId;
uniform float far;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    uniform float near;

    #ifndef IS_IRIS
        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;
    #else
        //uniform mat4 gbufferModelView;
        uniform mat4 gbufferProjection;
    #endif
#endif

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/scene.glsl"

    #ifdef LIGHT_COLOR_ENABLED
        #include "/lib/ssbo/lighting.glsl"
    #endif
#endif

#include "/lib/matrix.glsl"
#include "/lib/celestial/position.glsl"
#include "/lib/shadows/common.glsl"

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
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
    gColor = vColor[v];
    gBlockId = vBlockId[v];
    gViewPos = vViewPos[v];

    #ifdef PHYSICS_OCEAN
        physics_gLocalPosition = physics_vLocalPosition[v];
    #endif
}

void main() {
    if (renderStage == MC_RENDER_STAGE_ENTITIES) {
        #ifdef SHADOW_EXCLUDE_ENTITIES
            return;
        #endif

        if (entityId == ENTITY_LIGHTNING_BOLT) return;
    }

    #if defined IS_IRIS && !defined PHYSICS_OCEAN
        // Iris does not cull water backfaces
        if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT && vBlockId[0] == MATERIAL_WATER) {
            if (vNoV[0] <= 0.0 && vNoV[1] <= 0.0 && vNoV[2] <= 0.0) return;
        }
    #endif

    if (
        renderStage == MC_RENDER_STAGE_TERRAIN_SOLID ||
        renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT ||
        renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED ||
        renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT)
    {
        #ifdef SHADOW_EXCLUDE_FOLIAGE
            if (vBlockId[0] >= 10000 && vBlockId[0] <= 10004) return;
        #endif

        #ifdef LIGHT_COLOR_ENABLED
            switch (vBlockId[0]) {
                case MATERIAL_TORCH:
                    AddSceneLight(vOriginPos[0], vec4(blockLightColor, 15.0));
                    break;
                case MATERIAL_SOUL_TORCH:
                    AddSceneLight(vOriginPos[0], vec4(0.397, 0.738, 0.909, 8.0));
                    break;
                case MATERIAL_REDSTONE_TORCH:
                    AddSceneLight(vOriginPos[0], vec4(0.904, 0.338, 0.237, 2.0));
                    break;
            }
        #endif
    }

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec3 shadowOriginPos = (shadowModelViewEx * vec4(vOriginPos[0], 1.0)).xyz;
        int shadowTile = GetShadowCascade(shadowOriginPos, 2.0);
        if (shadowTile < 0) return;

        #ifndef SHADOW_EXCLUDE_ENTITIES
            if (renderStage == MC_RENDER_STAGE_ENTITIES && entityId == CSM_PLAYER_ID) shadowTile = 0;
        #endif

        int cascadeMin = max(shadowTile - 1, 0);
        int cascadeMax = min(shadowTile + 1, 3);

        for (int c = cascadeMin; c <= cascadeMax; c++) {
            if (c != shadowTile) {
                // duplicate geometry if intersecting overlapping cascades
                if (!CascadeIntersectsPosition(shadowOriginPos, c)) continue;
            }

            for (int v = 0; v < 3; v++) {
                ApplyCommonProperties(v);

                gShadowTilePos = shadowProjectionPos[c];

                gl_Position = cascadeProjection[c] * gl_in[v].gl_Position;

                // gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
                // gl_Position.xy = gl_Position.xy * 0.5 + shadowProjectionPos[c];
                // gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

                gl_Position.xy = gl_Position.xy * 0.5 + shadowProjectionPos[c] * 2.0 - 0.5;

                EmitVertex();
            }

            EndPrimitive();
        }
    #else
        #ifndef IRIS_FEATURE_SSBO
            mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
        #endif

        for (int v = 0; v < 3; v++) {
            ApplyCommonProperties(v);

            gl_Position = shadowProjectionEx * gl_in[v].gl_Position;

            #if SHADOW_TYPE == 2
                gl_Position.xyz = distort(gl_Position.xyz);
            #endif

            EmitVertex();
        }

        EndPrimitive();
    #endif
}
