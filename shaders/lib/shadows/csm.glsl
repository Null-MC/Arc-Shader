const float tile_dist[4] = float[](5, 12, 30, 80);

const vec3 _shadowTileColors[4] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0),
    vec3(1.0, 0.0, 1.0));


// tile: 0-3
vec2 GetShadowCascadeClipPos(const in int tile) {
    if (tile < 0) return vec2(10.0);

    vec2 pos;
    //pos.x = (tile % 2) * 0.5;
    pos.x = fract(tile / 2.0);
    pos.y = floor(float(tile) * 0.5) * 0.5;
    return pos;
}

int GetCascadeForScreenPos(const in vec2 pos) {
    if (pos.y < 0.5)
        return pos.x < 0.5 ? 0 : 1;
    else
        return pos.x < 0.5 ? 2 : 3;
}

#if !defined RENDER_FRAG
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

    // size: in world-space units
    mat4 BuildOrthoProjectionMatrix(const in float width, const in float height, const in float zNear, const in float zFar) {
        return mat4(
            vec4(2.0 / width, 0.0, 0.0, 0.0),
            vec4(0.0, 2.0 / height, 0.0, 0.0),
            vec4(0.0, 0.0, -2.0 / (zFar - zNear), 0.0),
            vec4(0.0, 0.0, -(zFar + zNear)/(zFar - zNear), 1.0));
    }

    mat4 BuildTranslationMatrix(const in vec3 delta) {
        return mat4(
            vec4(1.0, 0.0, 0.0, 0.0),
            vec4(0.0, 1.0, 0.0, 0.0),
            vec4(0.0, 0.0, 1.0, 0.0),
            vec4(delta, 1.0));
    }

    mat4 BuildScalingMatrix(const in vec3 scale) {
        return mat4(
            vec4(scale.x, 0.0, 0.0, 0.0),
            vec4(0.0, scale.y, 0.0, 0.0),
            vec4(0.0, 0.0, scale.z, 0.0),
            vec4(0.0, 0.0, 0.0, 1.0));
    }


    #if defined SHADOW_CSM_TIGHTEN || defined DEBUG_CSM_FRUSTUM
        void GetFrustumMinMax(const in mat4 matSceneToShadowProjection, out vec3 clipMin, out vec3 clipMax) {
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
                vec3 shadowClipPos = unproject(matSceneToShadowProjection * vec4(frustum[i], 1.0));

                if (i == 0) {
                    clipMin = shadowClipPos;
                    clipMax = shadowClipPos;
                }
                else {
                    clipMin = min(clipMin, shadowClipPos);
                    clipMax = max(clipMax, shadowClipPos);
                }
            }
        }
        
        vec3 GetCascadePaddedFrustumClipBounds(const in mat4 matShadowProjection) {
            return 1.0 - 1.5 * vec3(
                matShadowProjection[0].x,
                matShadowProjection[1].y,
               -matShadowProjection[2].z);
        }

        vec3 GetCascadePaddedFrustumClipBounds(const in mat4 matShadowProjection, const in float padding) {
            return 1.0 + padding * vec3(
                matShadowProjection[0].x,
                matShadowProjection[1].y,
               -matShadowProjection[2].z);
        }

        bool CascadeContainsPosition(const in vec3 shadowViewPos, const in mat4 matShadowProjection) {
            vec3 clipPos = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz;
            vec3 paddedSize = GetCascadePaddedFrustumClipBounds(matShadowProjection, -1.5);

            return clipPos.x > -paddedSize.x && clipPos.x < paddedSize.x
                && clipPos.y > -paddedSize.y && clipPos.y < paddedSize.y
                && clipPos.z > -paddedSize.z && clipPos.z < paddedSize.z;
        }

        bool CascadeIntersectsPosition(const in vec3 shadowViewPos, const in mat4 matShadowProjection) {
            vec3 clipPos = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz;
            vec3 paddedSize = GetCascadePaddedFrustumClipBounds(matShadowProjection, 1.5);

            return clipPos.x > -paddedSize.x && clipPos.x < paddedSize.x
                && clipPos.y > -paddedSize.y && clipPos.y < paddedSize.y
                && clipPos.z > -paddedSize.z && clipPos.z < paddedSize.z;
        }
    #endif

    void GetShadowCascadeProjectionMatrix_AsParts(const in mat4 matProjection, out vec3 scale, out vec3 translation) {
        scale.x = matProjection[0][0];
        scale.y = matProjection[1][1];
        scale.z = matProjection[2][2];

        translation = matProjection[3].xyz;
    }
#endif

#if !defined RENDER_FRAG
    mat4 GetShadowCascadeProjectionMatrix(const in float cascadeSizes[4], const in int cascade) {
        float cascadePaddedSize = cascadeSizes[cascade] * 2.0 + 3.0;

        float zNear = -far;
        float zFar = far * 2.0;

        mat4 matShadowProjection = BuildOrthoProjectionMatrix(cascadePaddedSize, cascadePaddedSize, zNear, zFar);

        #ifdef SHADOW_CSM_TIGHTEN
            #if SHADER_PLATFORM == PLATFORM_OPTIFINE
                mat4 matSceneProjectionRanged = gbufferPreviousProjection;
                mat4 matSceneModelView = gbufferPreviousModelView;
            #else
                mat4 matSceneProjectionRanged = gbufferProjection;
                mat4 matSceneModelView = gbufferModelView;
            #endif

            //mat4 matShadowModelView = shadowModelView;

            // project scene view frustum slices to shadow-view space and compute min/max XY bounds
            float rangeNear = cascade > 0 ? cascadeSizes[cascade - 1] : near;

            rangeNear = max(rangeNear - 3.0, near);
            float rangeFar = cascadeSizes[cascade] + 3.0;

            SetProjectionRange(matSceneProjectionRanged, rangeNear, rangeFar);

            mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * matSceneModelView);
            mat4 matSceneToShadow = matShadowProjection * shadowModelView * matModelViewProjectionInv;

            vec3 clipMin, clipMax;
            GetFrustumMinMax(matSceneToShadow, clipMin, clipMax);

            // add block padding to clip min/max
            vec2 blockPadding = 3.0 * vec2(
                matShadowProjection[0][0],
                matShadowProjection[1][1]);

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

#if (defined RENDER_VERTEX || defined RENDER_GEOMETRY) && defined RENDER_GBUFFER
    // returns: tile [0-3] or -1 if excluded
    int GetShadowCascade(const in mat4 matShadowProjections[4], const in vec3 blockPos) {
        #ifdef SHADOW_CSM_FITRANGE
            const int max = 3;
        #else
            const int max = 4;
        #endif

        for (int i = 0; i < max; i++) {
            #ifdef SHADOW_CSM_TIGHTEN
                if (CascadeContainsPosition(blockPos, matShadowProjections[i])) return i;
            #else
                if (blockPos.x > -cascadeSizes[i] && blockPos.x < cascadeSizes[i]
                 && blockPos.y > -cascadeSizes[i] && blockPos.y < cascadeSizes[i]) return i;
            #endif
        }

        #ifdef SHADOW_CSM_FITRANGE
            return 3;
        #else
            return -1;
        #endif
    }
#endif

mat4 GetShadowCascadeProjectionMatrix_FromParts(const in vec3 scale, const in vec3 translation) {
    return mat4(
        vec4(scale.x, 0.0, 0.0, 0.0),
        vec4(0.0, scale.y, 0.0, 0.0),
        vec4(0.0, 0.0, scale.z, 0.0),
        vec4(translation, 1.0));
}

float GetCascadeBias(const in float geoNoL, const in vec2 shadowProjectionSize) {
    float maxProjSize = max(shadowProjectionSize.x, shadowProjectionSize.y);
    float zRangeBias = 0.05 / (3.0 * far);

    maxProjSize = pow(maxProjSize, 1.3);

    #if SHADOW_FILTER == 1
        float xySizeBias = 0.004 * maxProjSize * shadowPixelSize;// * tile_dist_bias_factor * 4.0;
    #else
        float xySizeBias = 0.004 * maxProjSize * shadowPixelSize;// * tile_dist_bias_factor;
    #endif

    float bias = mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;

    return 0.0001;
}

#if defined RENDER_VERTEX && !defined RENDER_SHADOW
    void ApplyShadows(const in vec3 localPos, const in vec3 viewDir) {
        #ifndef SSS_ENABLED
            if (geoNoL > 0.0) {
        #endif
            #ifdef RENDER_SHADOW
                mat4 matShadowModelView = gl_ModelViewMatrix;
            #else
                mat4 matShadowModelView = shadowModelView;
            #endif

            vec3 shadowViewPos = (matShadowModelView * vec4(localPos, 1.0)).xyz;

            #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                float geoNoV = dot(vNormal, viewDir);

                vec3 localViewDir = normalize(cameraPosition);
                vec3 parallaxLocalPos = localPos + (localViewDir / geoNoV) * PARALLAX_DEPTH;
                vec3 parallaxShadowViewPos = (matShadowModelView * vec4(parallaxLocalPos, 1.0)).xyz;
            #endif

            float cascadeSizes[4];
            cascadeSizes[0] = GetCascadeDistance(0);
            cascadeSizes[1] = GetCascadeDistance(1);
            cascadeSizes[2] = GetCascadeDistance(2);
            cascadeSizes[3] = GetCascadeDistance(3);

            mat4 matShadowProjection0 = GetShadowCascadeProjectionMatrix(cascadeSizes, 0);
            mat4 matShadowProjection1 = GetShadowCascadeProjectionMatrix(cascadeSizes, 1);
            mat4 matShadowProjection2 = GetShadowCascadeProjectionMatrix(cascadeSizes, 2);
            mat4 matShadowProjection3 = GetShadowCascadeProjectionMatrix(cascadeSizes, 3);

            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection0, matShadowProjections_scale[0], matShadowProjections_translation[0]);
            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection1, matShadowProjections_scale[1], matShadowProjections_translation[1]);
            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection2, matShadowProjections_scale[2], matShadowProjections_translation[2]);
            GetShadowCascadeProjectionMatrix_AsParts(matShadowProjection3, matShadowProjections_scale[3], matShadowProjections_translation[3]);
        #ifndef SSS_ENABLED
            }
        #endif
    }
#endif
