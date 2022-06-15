#define RENDER_SHADOW

/*
const int shadowtex0Format = R32F;
const int shadowtex1Format = R32F;
*/

//fix artifacts when colored shadows are enabled
//const bool generateShadowMipmap = false;
//const bool shadowcolor0Nearest = false;
const bool shadowHardwareFiltering = true;
const bool shadowtex0Mipmap = false;
const bool shadowtex0Nearest = false;
const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;

const float shadowDistanceRenderMul = 1.0;


varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#if SHADOW_TYPE == 3
	flat varying vec2 shadowTilePos;
#endif

#ifdef RENDER_VERTEX
	in vec4 mc_Entity;
	in vec3 vaPosition;
	in vec3 at_midBlock;

	uniform mat4 shadowModelViewInverse;
	uniform float frameTimeCounter;
	uniform vec3 cameraPosition;
	uniform vec3 chunkOffset;

	#include "/lib/waving.glsl"

	#if SHADOW_TYPE == 3
		uniform int entityId;
		uniform float near;
		uniform float far;

		// uniform mat4 gbufferModelView;
		// uniform mat4 gbufferProjection;
		// NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
		uniform mat4 gbufferPreviousModelView;
		uniform mat4 gbufferPreviousProjection;

		#include "/lib/shadows/csm.glsl"
	#elif SHADOW_TYPE != 0
		#include "/lib/shadows/basic.glsl"
	#endif


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;

		#if defined SHADOW_EXCLUDE_ENTITIES
			if (mc_Entity.x == 0.0) {
				gl_Position = vec4(10.0);

				#if SHADOW_TYPE == 3
					shadowTilePos = vec2(1.0);
				#endif

				return;
			}
		#endif

		#ifdef SHADOW_EXCLUDE_FOLIAGE
			if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) {
				gl_Position = vec4(10.0);

				#if SHADOW_TYPE == 3
					shadowTilePos = vec2(1.0);
				#endif
			}
			else {
		#endif

		vec4 pos = gl_Vertex;

		#ifdef ENABLE_WAVING
			if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
				pos.xyz += GetWavingOffset();
		#endif

		#if SHADOW_TYPE == 3
			mat4 matShadowProjection[4];
			PrepareCascadeMatrices(matShadowProjection);

			int shadowTile = GetShadowTile(matShadowProjection);
			shadowTilePos = GetShadowTilePos(shadowTile);
			gl_Position = matShadowProjection[shadowTile] * (gl_ModelViewMatrix * pos);

			gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
			gl_Position.xy = gl_Position.xy * 0.5 + shadowTilePos;
			gl_Position.xy = gl_Position.xy * 2.0 - 1.0;
		#else
			gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * pos);

			#if SHADOW_TYPE == 2
				gl_Position.xyz = distort(gl_Position.xyz);
			#endif
		#endif

		#ifdef SHADOW_EXCLUDE_FOLIAGE
			}
		#endif
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D lightmap;
	uniform sampler2D texture;


	void main() {
		#if SHADOW_TYPE == 3
			vec2 p = gl_FragCoord.xy / shadowMapResolution - shadowTilePos;

			if (p.x < 0 || p.x >= 0.5) discard;
			if (p.y < 0 || p.y >= 0.5) discard;
		#endif

		vec4 color = texture2D(texture, texcoord) * glcolor;

		gl_FragData[0] = color;
	}
#endif
