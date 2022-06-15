#define RENDER_COMPOSITE

#if SHADOW_TYPE == 3
	uniform mat4 shadowModelView;
	uniform float near;
	uniform float far;
#endif

varying vec2 texcoord;

#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
	varying vec3 shadowTileColors[4];
	varying mat4 matShadowToScene[4];
	varying vec3 clipMin[4];
	varying vec3 clipMax[4];
#endif

#ifdef RENDER_VERTEX
	#if SHADOW_TYPE == 3
		uniform mat4 gbufferModelView;
		uniform mat4 gbufferPreviousModelView;
		uniform mat4 gbufferProjection;
		uniform mat4 shadowProjection;
		
		#include "/lib/shadows/csm.glsl"
	#endif


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

		#if SHADOW_TYPE == 3 && defined DEBUG_CSM_FRUSTUM && DEBUG_SHADOW_BUFFER != 0
			mat4 matShadowModelView = GetShadowModelViewMatrix();

			for (int tile = 0; tile < 4; tile++) {
				vec2 shadowTilePos = GetShadowTilePos(tile);
				shadowTileColors[tile] = GetShadowTileColor(tile);

				float rangeNear = tile > 0 ? GetCascadeDistance(tile - 1) : near;
				float rangeFar = GetCascadeDistance(tile);
				mat4 matSceneProjectionRanged = gbufferProjection;
				SetProjectionRange(matSceneProjectionRanged, rangeNear, rangeFar);

				mat4 matShadowProjection = GetShadowTileProjectionMatrix(tile);
				mat4 matShadowWorldViewProjectionInv = inverse(matShadowProjection * matShadowModelView);
				matShadowToScene[tile] = matSceneProjectionRanged * gbufferModelView * matShadowWorldViewProjectionInv;

				// project frustum points
				mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * gbufferModelView);
				mat4 matSceneToShadow = matShadowProjection * matShadowModelView * matModelViewProjectionInv;

				GetFrustumMinMax(matSceneToShadow, clipMin[tile], clipMax[tile]);
			}
		#endif
	}
#endif

#ifdef RENDER_FRAG
	uniform float frameTimeCounter;

	uniform sampler2D gcolor;
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;


	void main() {
		#if DEBUG_SHADOW_BUFFER == 1
			vec3 color = texture2D(shadowcolor0, texcoord).rgb;
		#elif DEBUG_SHADOW_BUFFER == 2
			vec3 color = texture2D(shadowtex0, texcoord).rrr;
		#elif DEBUG_SHADOW_BUFFER == 3
			vec3 color = texture2D(shadowtex1, texcoord).rrr;
		#else
			vec3 color = texture2D(gcolor, texcoord).rgb;
		#endif

		#if defined DEBUG_CSM_FRUSTUM && SHADOW_TYPE == 3 && DEBUG_SHADOW_BUFFER != 0
			int tile;
			if (texcoord.y < 0.5)
				tile = texcoord.x < 0.5 ? 0 : 1;
			else
				tile = texcoord.x < 0.5 ? 2 : 3;

			vec3 clipPos;
			clipPos.xy = fract(texcoord * 2.0);
			clipPos.z = texture2D(shadowtex0, texcoord).r;
			clipPos = clipPos * 2.0 - 1.0;

			vec4 sceneClipPos = matShadowToScene[tile] * vec4(clipPos, 1.0);
			sceneClipPos.xyz /= sceneClipPos.w;

			bool frustum_contained = true;
			if (sceneClipPos.x < -1.0 || sceneClipPos.x > 1.0) frustum_contained = false;
			if (sceneClipPos.y < -1.0 || sceneClipPos.y > 1.0) frustum_contained = false;
			if (sceneClipPos.z < -1.0 || sceneClipPos.z > 1.0) frustum_contained = false;

			bool bounds_contained = true;
			if (clipPos.x < clipMin[tile].x || clipPos.x > clipMax[tile].x) bounds_contained = false;
			if (clipPos.y < clipMin[tile].y || clipPos.y > clipMax[tile].y) bounds_contained = false;

			if (frustum_contained && clipPos.z < 1.0) {
				color *= vec3(1.0, 0.2, 0.2);
			}
			else if (bounds_contained) {
				color *= vec3(1.0, 1.0, 0.2);
			}
			else {
				#ifdef DEBUG_CASCADE_TINT
					color *= 1.0 - LOD_TINT_FACTOR * (1.0 - shadowTileColors[tile]);
				#endif
			}
		#endif

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(color, 1.0); //gcolor
	}
#endif
