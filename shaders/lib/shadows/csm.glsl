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

#if !defined RENDER_FRAG || defined RENDER_DEFERRED
    // tile: 0-3
    float GetCascadeDistance(const in int tile) {
        float maxDist = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);

        if (tile == 2) {
            return tile_dist[2] + max(maxDist - tile_dist[2], 0.0) * SHADOW_CSM_FITSCALE;
        }
        else if (tile == 3) {
            return maxDist;
        }

        return tile_dist[tile];
    }

    void SetProjectionRange(inout mat4 matProj, const in float zNear, const in float zFar) {
        matProj[2][2] = -(zFar + zNear) / (zFar - zNear);
        matProj[3][2] = -(2.0 * zFar * zNear) / (zFar - zNear);
    }

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
#endif

#if !defined RENDER_FRAG
    mat4 GetShadowCascadeProjectionMatrix(const in int cascade, out vec2 shadowViewMin, out vec2 shadowViewMax) {
        float cascadePaddedSize = cascadeSize[cascade] * 2.0 + 3.0;

        float zNear = -far;
        float zFar = far * 2.0;

        mat4 matShadowProjection = BuildOrthoProjectionMatrix(cascadePaddedSize, cascadePaddedSize, zNear, zFar);

        #ifndef IS_IRIS
            mat4 matSceneProjectionRanged = gbufferPreviousProjection;
            mat4 matSceneModelView = gbufferPreviousModelView;
        #else
            mat4 matSceneProjectionRanged = gbufferProjection;
            mat4 matSceneModelView = gbufferModelView;
        #endif

        #ifndef IRIS_FEATURE_SSBO
            mat4 shadowModelViewEx = BuildShadowViewMatrix();
        #endif

        // project scene view frustum slices to shadow-view space and compute min/max XY bounds
        float rangeNear = cascade > 0 ? cascadeSize[cascade - 1] : near;

        rangeNear = max(rangeNear - 3.0, near);
        float rangeFar = cascadeSize[cascade] + 3.0;

        SetProjectionRange(matSceneProjectionRanged, rangeNear, rangeFar);

        mat4 matModelViewProjectionInv = inverse(matSceneProjectionRanged * matSceneModelView);
        mat4 matSceneToShadow = matShadowProjection * (shadowModelViewEx * matModelViewProjectionInv);

        vec3 clipMin, clipMax;
        GetFrustumMinMax(matSceneToShadow, clipMin, clipMax);

        clipMin = max(clipMin, vec3(-1.0));
        clipMax = min(clipMax, vec3( 1.0));

        float viewScale = 2.0 / cascadePaddedSize;
        shadowViewMin = clipMin.xy / viewScale;
        shadowViewMax = clipMax.xy / viewScale;

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
        return matProjScale * (matProjTranslate * matShadowProjection);
    }
#endif

bool CascadeContainsPosition(const in vec3 shadowViewPos, const in int cascade, const in float padding) {
    return all(greaterThan(shadowViewPos.xy + padding, cascadeViewMin[cascade]))
        && all(lessThan(shadowViewPos.xy - padding, cascadeViewMax[cascade]));
}

bool CascadeIntersectsPosition(const in vec3 shadowViewPos, const in int cascade) {
    return all(greaterThan(shadowViewPos.xy + 2.0, cascadeViewMin[cascade]))
        && all(lessThan(shadowViewPos.xy - 2.0, cascadeViewMax[cascade]));
}

int GetShadowCascade(const in vec3 shadowViewPos, const in float padding) {
    if (CascadeContainsPosition(shadowViewPos, 0, padding)) return 0;
    if (CascadeContainsPosition(shadowViewPos, 1, padding)) return 1;
    if (CascadeContainsPosition(shadowViewPos, 2, padding)) return 2;
    if (CascadeContainsPosition(shadowViewPos, 3, padding)) return 3;
    return -1;
}

float GetCascadeBias(const in float geoNoL, const in vec2 shadowProjectionSize) {
    // float maxProjSize = max(shadowProjectionSize.x, shadowProjectionSize.y);
    // float zRangeBias = 0.05 / (3.0 * far);

    // maxProjSize = pow(maxProjSize, 1.3);

    // #if SHADOW_FILTER == 1
    //     float xySizeBias = 0.004 * maxProjSize * shadowPixelSize;// * tile_dist_bias_factor * 4.0;
    // #else
    //     float xySizeBias = 0.004 * maxProjSize * shadowPixelSize;// * tile_dist_bias_factor;
    // #endif

    // float bias = mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;

    return 0.00004;
}
