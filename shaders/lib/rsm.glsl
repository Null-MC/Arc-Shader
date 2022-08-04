float SampleDepth(const in ivec2 itex) {
    #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
        return texelFetch(shadowtex1, itex, 0).r;
    #elif defined SHADOW_ENABLE_HWCOMP
        return texelFetch(shadowtex0, itex, 0).r;
    #else
        return texelFetch(shadowtex1, itex, 0).r;
    #endif
}

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    vec3 GetNearestDepth(const in vec3 shadowViewPos, out ivec2 uv_out, out int cascade) {
        float depth = 1.0;
        vec2 pos_out = vec2(0.0);
        uv_out = ivec2(0);
        cascade = -1;

        float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

        for (int i = 0; i < 4; i++) {
            vec3 shadowPos = (matShadowProjections[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;

            // Ignore if outside cascade bounds
            if (shadowPos.x < 0.0 || shadowPos.x >= 1.0
             || shadowPos.y < 0.0 || shadowPos.y >= 1.0) continue;

            vec2 shadowTilePos = GetShadowCascadeClipPos(i);
            ivec2 iuv = ivec2((shadowTilePos + 0.5 * shadowPos.xy) * shadowMapSize);
            
            //float texDepth = texelFetch(shadowtex1, iuv, 0).r;
            float texDepth = SampleDepth(iuv);

            if (texDepth < depth) {
                depth = texDepth;
                pos_out = shadowPos.xy;
                uv_out = iuv;
                cascade = i;
            }
        }

        return vec3(pos_out, depth);
    }
#endif

vec3 GetIndirectLighting_RSM(const in vec3 shadowViewPos, const in vec3 shadowViewNormal) {
    // Sum contributions of sampling locations.
    vec3 shading = vec3(0.0);

    //#if SHADOW_TYPE != SHADOW_TYPE_CASCADED
    //  mat4 matShadowClipToLocal = shadowModelViewInverse * shadowProjectionInverse;
    //#endif

    for (int i = 0; i < RSM_SAMPLE_COUNT; i++) {
        vec3 offsetShadowViewPos = shadowViewPos;
        offsetShadowViewPos.xy += rsmPoissonDisk[i] * RSM_FILTER_SIZE;

        vec2 uv;
        ivec2 iuv;
        vec3 x_p;
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            int cascade;
            vec3 clipPos = GetNearestDepth(offsetShadowViewPos, iuv, cascade);

            vec3 shadowViewPos2 = offsetShadowViewPos;
            shadowViewPos2.z = -clipPos.z * far * 3.0 + far;

            x_p = shadowViewPos2;
        #else
            vec3 clipPos = (shadowProjection * vec4(offsetShadowViewPos, 1.0)).xyz;

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                uv = distort(clipPos).xy * 0.5 + 0.5;
            #else
                uv = clipPos.xy * 0.5 + 0.5;
            #endif

            iuv = ivec2(uv * shadowMapSize);

            //clipPos.z = texelFetch(shadowtex1, iuv, 0).r * 2.0 - 1.0;
            clipPos.z = SampleDepth(iuv);
            clipPos.z = clipPos.z * 2.0 - 1.0;

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                clipPos.z *= 2.0;
            #endif

            //x_p = (shadowProjectionInverse * vec4(clipPos, 1.0)).xyz;
            x_p = offsetShadowViewPos;
            x_p.z = clipPos.z * shadowProjectionInverse[2][2] + shadowProjectionInverse[3][2];
        #endif

        uvec2 data = texelFetch(shadowcolor1, iuv, 0).rg;

        // Irradiance at current fragment w.r.t. pixel light at uv.
        vec3 ray = shadowViewPos - x_p; // Difference vector.
        vec3 rayDir = normalize(ray);
        float rayDist = dot(ray, ray); // Square distance.

        vec2 normalMap = unpackUnorm4x8(data.g).rg;
        vec3 n_p = RestoreNormalZ(normalMap);
        //n_p = mat3(shadowModelViewInverse) * n_p;

        vec3 flux = unpackUnorm4x8(data.r).rgb;
        flux = RGBToLinear(flux);

        float NoL = max(dot(n_p, vec3(0.0, 0.0, 1.0)), 0.0);
        float NoR = max(dot(n_p, rayDir), 0.0);

        vec3 E_p = flux * NoR;

        // Weighting contribution and normalizing.
        //float weight = rsmPoissonDisk[i].x * rsmPoissonDisk[i].x;
        float weight = dot(rsmPoissonDisk[i], rsmPoissonDisk[i]);
        E_p *= weight / rayDist;

        // Accumulate
        shading += E_p;
    }

    // Modulate result with some intensity value.
    return (shading / RSM_SAMPLE_COUNT) * RSM_INTENSITY * RSM_FILTER_SIZE;
}
