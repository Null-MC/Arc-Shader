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

#ifdef LIGHT_COLOR_ENABLED
    uniform sampler3D TEX_CLOUD_NOISE;

    uniform float frameTimeCounter;
#endif

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
#include "/lib/sampling/noise.glsl"
#include "/lib/lighting/blackbody.glsl"
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
    gBlockId = vBlockId[v];
    gViewPos = vViewPos[v];
    gColor = vColor[v];

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
            vec4 lightColor = vec4(0.0);
            vec3 lightOffset = vec3(0.0);
            float flicker = 0.0;

            #ifdef LIGHT_FLICKER_ENABLED
                float time = frameTimeCounter / 3600.0;
                vec3 worldPos = cameraPosition + vOriginPos[0];

                vec3 texPos = fract(worldPos.xzy * vec3(0.02, 0.02, 0.04));
                texPos.z += 1200.0 * time;

                float flickerNoise = texture(TEX_CLOUD_NOISE, texPos).g;
            #endif

            switch (vBlockId[0]) {
                case MATERIAL_SEA_LANTERN:
                    lightColor = vec4(0.635, 0.909, 0.793, 15.0);
                    break;
                case MATERIAL_REDSTONE_LAMP:
                    lightColor = vec4(0.953, 0.796, 0.496, 15.0);
                    break;
                case MATERIAL_TORCH:
                    #ifdef LIGHT_FLICKER_ENABLED
                        float temp = mix(2400, 3600, 1.0 - flickerNoise);
                        lightColor = vec4(blackbody(temp), 12.0);
                    #else
                        lightColor = vec4(0.934, 0.771, 0.395, 12.0);
                    #endif
                    flicker = 0.16;
                    break;
                case MATERIAL_LANTERN:
                    lightColor = vec4(0.906, 0.737, 0.451, 12.0);
                    break;
                case MATERIAL_SOUL_TORCH:
                    lightColor = vec4(0.510, 0.831, 0.851, 12.0);
                    break;
                case MATERIAL_REDSTONE_TORCH:
                    lightColor = vec4(0.992, 0.471, 0.357, 7.0);
                    break;
                case MATERIAL_MAGMA:
                    lightColor = vec4(0.804, 0.424, 0.149, 3.0);
                    break;
                case MATERIAL_GLOWSTONE:
                    lightColor = vec4(0.742, 0.668, 0.468, 15.0);
                    break;
                case MATERIAL_GLOW_LICHEN:
                    lightColor = vec4(0.232, 0.414, 0.214, 7.0);
                    break;
                case MATERIAL_END_ROD:
                    lightColor = vec4(0.957, 0.929, 0.875, 14.0);
                    break;
                case MATERIAL_FIRE:
                    lightColor = vec4(0.851, 0.616, 0.239, 15.0);
                    break;
                case MATERIAL_NETHER_PORTAL:
                    lightColor = vec4(0.502, 0.165, 0.831, 11.0);
                    break;
                case MATERIAL_CAVEVINE_BERRIES:
                    lightColor = vec4(0.717, 0.541, 0.188, 14.0);
                    break;
                case MATERIAL_AMETHYST_CLUSTER:
                    lightColor = vec4(0.537, 0.412, 0.765, 5.0);
                    break;
                case MATERIAL_BREWING_STAND:
                    lightColor = vec4(0.636, 0.509, 0.179, 3.0);
                    break;
            }

            if (any(greaterThan(lightColor, vec4(EPSILON)))) {
                if (vBlockId[0] == MATERIAL_TORCH) {
                    //vec3 texPos = worldPos.xzy * vec3(0.04, 0.04, 0.02);
                    //texPos.z += 2.0 * time;

                    //vec2 s = texture(TEX_CLOUD_NOISE, texPos).rg;

                    //lightOffset = 0.08 * hash44(vec4(worldPos * 0.04, 2.0 * time)).xyz - 0.04;
                    //lightOffset = 0.12 * hash44(vec4(worldPos * 0.04, 4.0 * time)).xyz - 0.06;
                }

                #ifdef LIGHT_FLICKER_ENABLED
                    if (flicker > EPSILON) {
                        lightColor.rgb *= 1.0 - flicker * flickerNoise;
                    }
                #endif

                AddSceneLight(vOriginPos[0] + lightOffset, lightColor);
            }
        #endif
    }

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec3 shadowOriginPos = vOriginPos[0] + fract(cameraPosition);
        shadowOriginPos = (shadowModelViewEx * vec4(shadowOriginPos, 1.0)).xyz;
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
