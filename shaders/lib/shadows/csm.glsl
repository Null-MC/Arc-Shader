const float tile_dist[4] = float[](5, 12, 30, 80);

const vec3 _shadowTileColors[4] = vec3[](
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0),
	vec3(1.0, 0.0, 1.0));

// tile: 0-3
vec2 GetShadowTilePos(const in int tile) {
	vec2 pos;
	pos.x = (tile % 2) * 0.5;
	pos.y = floor(float(tile) * 0.5) * 0.5;
	return pos;
}

// tile: 0-3
vec3 GetShadowTileColor(const in int tile) {
	if (tile < 0) return vec3(1.0);
	return _shadowTileColors[tile];
}

#ifdef RENDER_VERTEX
	// tile: 0-3
	float GetCascadeDistance(const in int tile) {
		#ifdef SHADOW_CSM_FITRANGE
			float maxDist = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);

			if (tile == 2) {
				return tile_dist[2] + max(maxDist - tile_dist[2], 0.0) * SHADOW_CSM_FITSCALE;
			}
			else if (tile == 3) {
				return maxDist;
			}
		#endif

		return tile_dist[tile];
	}

	void SetProjectionRange(inout mat4 matProj, const in float zNear, const in float zFar) {
		matProj[2][2] = -(zFar + zNear) / (zFar - zNear);
		matProj[3][2] = -(2.0 * zFar * zNear) / (zFar - zNear);
	}
#endif

#ifdef RENDER_VERTEX
	mat4 GetShadowTileViewMatrix() {
		#ifdef RENDER_SHADOW
			return gl_ModelViewMatrix;
		#else
			return shadowModelView;
		#endif
	}

	// size: in world-space units
	mat4 BuildOrthoProjectionMatrix(const in float width, const in float height, const in float zNear, const in float zFar) {
		return mat4(
		    vec4(2.0 / width, 0.0, 0.0, 0.0),
		    vec4(0.0, 2.0 / height, 0.0, 0.0),
		    vec4(0.0, 0.0, -2.0 / (zFar - zNear), 0.0),
		    vec4(0.0, 0.0, -(zFar + zNear)/(zFar - zNear), 1.0));
	}

	mat4 BuildTranslationMatrix(const in vec3 delta)
	{
	    return mat4(
	        vec4(1.0, 0.0, 0.0, 0.0),
	        vec4(0.0, 1.0, 0.0, 0.0),
	        vec4(0.0, 0.0, 1.0, 0.0),
	        vec4(delta, 1.0));
	}

	mat4 BuildScalingMatrix(const in vec3 scale)
	{
	    return mat4(
	        vec4(scale.x, 0.0, 0.0, 0.0),
	        vec4(0.0, scale.y, 0.0, 0.0),
	        vec4(0.0, 0.0, scale.z, 0.0),
	        vec4(0.0, 0.0, 0.0, 1.0));
	}

	mat4 GetShadowModelViewMatrix() {
		#ifdef RENDER_SHADOW
			return gl_ModelViewMatrix;
		#else
			return shadowModelView;
		#endif
	}

	#if defined SHADOW_CSM_TIGHTEN || defined DEBUG_CSM_FRUSTUM
		void GetFrustumMinMax(const in mat4 matProjection, out vec3 clipMin, out vec3 clipMax) {
			vec3 frustum[8] = vec3[](
				vec3(-1.0, -1.0, -1.0),
				vec3( 1.0, -1.0, -1.0),
				vec3(-1.0,  1.0, -1.0),
				vec3( 1.0,  1.0, -1.0),
				vec3(-1.0, -1.0,  1.0),
				vec3( 1.0, -1.0,  1.0),
				vec3(-1.0,  1.0,  1.0),
				vec3( 1.0,  1.0,  1.0));

			for (int i = 0; i < 8; i++) {
				vec4 shadowClipPos = matProjection * vec4(frustum[i], 1.0);
				shadowClipPos.xyz /= shadowClipPos.w;

				if (i == 0) {
					clipMin = shadowClipPos.xyz;
					clipMax = shadowClipPos.xyz;
				}
				else {
					clipMin = min(clipMin, shadowClipPos.xyz);
					clipMax = max(clipMax, shadowClipPos.xyz);
				}
			}
		}
	#endif

	mat4 GetShadowTileProjectionMatrix(const in int tile) {
		float tileSize = GetCascadeDistance(tile);
		float cascadeSize = tileSize * 2.0 + 3.0;

		float zNear = -far;
		float zFar = far;

		// TESTING: reduce the depth-range for the nearest cascade only
		//if (tile == 0) zNear = 0.0;

		mat4 matShadowProjection = BuildOrthoProjectionMatrix(cascadeSize, cascadeSize, zNear, zFar);

		#ifdef SHADOW_CSM_TIGHTEN
			#ifdef RENDER_SHADOW
				mat4 matSceneProjectionRanged = gbufferPreviousProjection;
				mat4 matSceneModelView = gbufferPreviousModelView;
				mat4 matShadowModelView = gl_ModelViewMatrix;
			#else
				mat4 matSceneProjectionRanged = gbufferProjection;
				mat4 matSceneModelView = gbufferPreviousModelView; //gbufferModelView; FIX for broken OF shadow pass
				mat4 matShadowModelView = shadowModelView;
			#endif
			
			// project scene view frustum slices to shadow-view space and compute min/max XY bounds
			float rangeNear = tile > 0 ? GetCascadeDistance(tile - 1) : near;

			rangeNear = max(rangeNear - 3.0, near);
			float rangeFar = tileSize + 3.0;

			SetProjectionRange(matSceneProjectionRanged, rangeNear, rangeFar);

			mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * matSceneModelView);
			mat4 matSceneToShadow = matShadowProjection * matShadowModelView * matModelViewProjectionInv;

			vec3 clipMin, clipMax;
			GetFrustumMinMax(matSceneToShadow, clipMin, clipMax);

			// add block padding to clip min/max
			vec2 blockPadding = 3.0 * vec2(matShadowProjection[0][0], matShadowProjection[1][1]);
			clipMin.xy -= blockPadding;
			clipMax.xy += blockPadding;

			clipMin = max(clipMin, vec3(-1.0));
			clipMax = min(clipMax, vec3( 1.0));

			// offset & scale frustum clip bounds to fullsize
			vec2 center = (clipMin.xy + clipMax.xy) * 0.5;
			vec2 scale = 2.0 / (clipMax.xy - clipMin.xy);
			mat4 matProjScale = BuildScalingMatrix(vec3(scale, 1.0));
			mat4 matProjTranslate = BuildTranslationMatrix(vec3(-center, 0.0));
			matShadowProjection = matProjScale * matProjTranslate * matShadowProjection;
		#endif

		return matShadowProjection;
	}
#endif

#if defined RENDER_VERTEX && !defined RENDER_COMPOSITE
	void PrepareCascadeMatrices(out mat4 matProj[4]) {
		for (int i = 0; i < 4; i++)
			matProj[i] = GetShadowTileProjectionMatrix(i);
	}

	vec3 GetBlockPos() {
		#ifndef SHADOW_EXCLUDE_ENTITIES
			#if defined RENDER_TERRAIN || defined RENDER_SHADOW
				if (mc_Entity.x == 0.0) return vec3(0.0);
			#elif defined RENDER_ENTITIES
				return vec3(0.0);
			#endif
		#endif

		#ifdef RENDER_SHADOW
			vec3 midBlockPosition = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));
			vec4 pos = gl_ModelViewMatrix * vec4(midBlockPosition, 1.0);
		#elif defined RENDER_TERRAIN
			vec3 midBlockPosition = floor(vaPosition + chunkOffset + at_midBlock / 64.0 + fract(cameraPosition));
			vec4 pos = shadowModelView * vec4(midBlockPosition, 1.0);
		#else
			vec4 pos = gl_Vertex;
			pos.xyz = floor(pos.xyz + 0.5);
			pos = shadowModelView * pos;
		#endif

		return pos.xyz;
	}

	// returns: tile [0-3] or -1 if excluded
	int GetShadowTile(const in mat4 matShadowProjection[4]) {
		vec3 blockPos = GetBlockPos();

		#ifndef SHADOW_EXCLUDE_ENTITIES
			#if defined RENDER_SHADOW
				if (entityId == CSM_PLAYER_ID) return 0;
				if (mc_Entity.x == 0.0) return SHADOW_ENTITY_CASCADE;
			#elif defined RENDER_TERRAIN
				if (mc_Entity.x == 0.0) return SHADOW_ENTITY_CASCADE;
			#elif defined RENDER_ENTITIES
				if (entityId == CSM_PLAYER_ID) return 0;
				return SHADOW_ENTITY_CASCADE;
			#endif
		#else
			#if defined RENDER_SHADOW || defined RENDER_TERRAIN
				if (mc_Entity.x == 0.0) return -1;
			#elif defined RENDER_ENTITIES
				return -1;
			#endif
		#endif

		#ifdef SHADOW_CSM_FITRANGE
			const int max = 3;
		#else
			const int max = 4;
		#endif

		for (int i = 0; i < max; i++) {
			#ifdef SHADOW_CSM_TIGHTEN
				vec4 clipPos = matShadowProjection[i] * vec4(blockPos, 1.0);

				vec3 blockPadding = 1.5 * vec3(
					matShadowProjection[i][0].x,
					matShadowProjection[i][1].y,
					-matShadowProjection[i][2].z);

				vec3 paddedSize = 1.0 - blockPadding;

				if (clipPos.x > -paddedSize.x && clipPos.x < paddedSize.x
				 && clipPos.y > -paddedSize.y && clipPos.y < paddedSize.y
				 && clipPos.z > -paddedSize.z && clipPos.z < paddedSize.z) return i;
			#else
				float size = GetCascadeDistance(i);

				if (blockPos.x > -size && blockPos.x < size
				 && blockPos.y > -size && blockPos.y < size) return i;
			#endif
		}

		#ifdef SHADOW_CSM_FITRANGE
			return 3;
		#else
			return -1;
		#endif
	}
#endif
