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
    vec3 shading = vec3(0.0);

    for (int i = 0; i < RSM_SAMPLE_COUNT; i++) {
        vec3 offsetShadowViewPos = shadowViewPos;
        offsetShadowViewPos.xy += rsmPoissonDisk[i] * RSM_FILTER_SIZE;

        vec2 uv;
        ivec2 iuv;
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            int cascade;
            float sampleDepth = GetNearestDepth(offsetShadowViewPos, iuv, cascade).z;

            vec3 samplePos = offsetShadowViewPos;
            samplePos.z = -sampleDepth * far * 3.0 + far;
        #else
            vec3 clipPos = (shadowProjection * vec4(offsetShadowViewPos, 1.0)).xyz;

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                uv = distort(clipPos).xy * 0.5 + 0.5;
            #else
                uv = clipPos.xy * 0.5 + 0.5;
            #endif

            iuv = ivec2(uv * shadowMapSize);
            clipPos.z = SampleDepth(iuv) * 2.0 - 1.0;

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                clipPos.z *= 2.0;
            #endif

            vec3 samplePos = offsetShadowViewPos;
            samplePos.z = clipPos.z * shadowProjectionInverse[2][2] + shadowProjectionInverse[3][2];
        #endif

        uvec2 data = texelFetch(shadowcolor1, iuv, 0).rg;

        vec3 ray = samplePos - shadowViewPos;
        vec3 rayDir = normalize(ray);

        vec3 sampleNormal = unpackUnorm4x8(data.g).rgb;
        sampleNormal = normalize(sampleNormal * 2.0 - 1.0);

        vec3 sampleColor = unpackUnorm4x8(data.r).rgb;
        sampleColor = RGBToLinear(sampleColor);

        float NoR1 = max(dot(shadowViewNormal, rayDir), 0.0);
        float NoR2 = max(dot(sampleNormal, -rayDir), 0.0);

        sampleColor *= NoR1 * NoR2;

        float weight = dot(rsmPoissonDisk[i], rsmPoissonDisk[i]);
        weight = max(1.0 - weight, 0.0) / length(ray);

        shading += sampleColor * weight;
    }

    return (shading / RSM_SAMPLE_COUNT) * RSM_INTENSITY * RSM_FILTER_SIZE;
}
