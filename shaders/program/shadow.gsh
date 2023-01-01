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
flat in int vBlockId[3];
flat in int vEntityId[3];

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
	flat in vec3 vOriginPos[3];
#endif

#ifdef SSS_ENABLED
    flat in float vMaterialSSS[3];
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    in vec3 vViewPos[3];
#endif

#if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
    flat in mat3 vMatShadowViewTBN[3];
#endif

#ifdef RSM_ENABLED
    flat in mat3 vMatViewTBN[3];
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    flat in int vWaterMask[3];
#endif

out vec3 gLocalPos;
out vec2 gTexcoord;
out vec2 gLmcoord;
out vec4 gColor;
flat out int gBlockId;
flat out int gEntityId;

#ifdef SSS_ENABLED
    flat out float gMaterialSSS;
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    out vec3 gViewPos;
#endif

#if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
    flat out mat3 gMatShadowViewTBN;
#endif

#ifdef RSM_ENABLED
    flat out mat3 gMatViewTBN;
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    flat out int gWaterMask;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
	flat out vec2 gShadowTilePos;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;
uniform int renderStage;

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
	gEntityId = vEntityId[v];

	#ifdef SSS_ENABLED
	    gMaterialSSS = vMaterialSSS[v];
	#endif

	#if defined RSM_ENABLED || (defined WATER_FANCY)
	    gViewPos = vViewPos[v];
	#endif

	#if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
	    gMatShadowViewTBN = vMatShadowViewTBN[v];
	#endif

	#ifdef RSM_ENABLED
	    gMatViewTBN = vMatViewTBN[v];
	#endif

	#if defined WATER_FANCY && !defined WORLD_NETHER
	    gWaterMask = vWaterMask[v];
	#endif

	#ifdef PHYSICS_OCEAN
		physics_gLocalPosition = physics_vLocalPosition[v];
	#endif
}

void main() {
	#ifdef SHADOW_EXCLUDE_ENTITIES
		if (vEntityId[0] == 0) return;
	#endif

	#ifdef SHADOW_EXCLUDE_FOLIAGE
		if (vBlockId[0] >= 10000 && vBlockId[0] <= 10004) return;
	#endif

    if (vEntityId[0] == MATERIAL_LIGHTNING_BOLT) return;

	#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
		float cascadeSizes[4];
        cascadeSizes[0] = GetCascadeDistance(0);
        cascadeSizes[1] = GetCascadeDistance(1);
        cascadeSizes[2] = GetCascadeDistance(2);
        cascadeSizes[3] = GetCascadeDistance(3);

		mat4 matShadowProjections[4];
		matShadowProjections[0] = GetShadowCascadeProjectionMatrix(cascadeSizes, 0);
		matShadowProjections[1] = GetShadowCascadeProjectionMatrix(cascadeSizes, 1);
		matShadowProjections[2] = GetShadowCascadeProjectionMatrix(cascadeSizes, 2);
		matShadowProjections[3] = GetShadowCascadeProjectionMatrix(cascadeSizes, 3);

		int shadowTile = GetShadowCascade(matShadowProjections, vOriginPos[0]);
		if (shadowTile < 0) return;

		#ifndef SHADOW_EXCLUDE_ENTITIES
			if (renderStage == MC_RENDER_STAGE_ENTITIES && vEntityId[0] == CSM_PLAYER_ID) shadowTile = 0;
		#endif

		int cascadeMin = max(shadowTile - 1, 0);
		int cascadeMax = min(shadowTile + 1, 3);

		for (int c = cascadeMin; c <= cascadeMax; c++) {
			if (c != shadowTile) {
				// duplicate geometry if intersecting overlapping cascades
				if (!CascadeIntersectsPosition(vOriginPos[0], matShadowProjections[c])) continue;
			}

			vec2 shadowTilePos = GetShadowCascadeClipPos(c);

			for (int v = 0; v < 3; v++) {
				ApplyCommonProperties(v);

				gShadowTilePos = shadowTilePos;

				gl_Position = matShadowProjections[c] * gl_in[v].gl_Position;

				gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
				gl_Position.xy = gl_Position.xy * 0.5 + shadowTilePos;
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
