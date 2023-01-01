float SampleDepth(const in vec2 tex) {
    #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
        return textureLod(shadowtex1, tex, 0).r;
    //#elif defined SHADOW_ENABLE_HWCOMP
    #else
        return textureLod(shadowtex0, tex, 0).r;
    //#else
    //    return texelFetch(shadowtex1, itex, 0).r;
    #endif
}

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    vec3 GetNearestDepth(const in mat4 matShadowProjection[4], const in vec3 shadowViewPos, out vec2 uv_out, out int cascade) {
        float depth = 1.0;
        vec2 pos_out = vec2(0.0);
        uv_out = vec2(0);
        cascade = -1;

        float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

        for (int i = 0; i < 4; i++) {
            vec3 shadowPos = (matShadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;

            // Ignore if outside cascade bounds
            if (shadowPos != saturate(shadowPos)) continue;

            vec2 shadowTilePos = GetShadowCascadeClipPos(i);
            vec2 uv = shadowTilePos + 0.5 * shadowPos.xy;
            
            //float texDepth = texelFetch(shadowtex1, iuv, 0).r;
            float texDepth = SampleDepth(uv);

            if (texDepth < depth) {
                depth = texDepth;
                pos_out = shadowPos.xy;
                uv_out = uv;
                cascade = i;
            }
        }

        return vec3(pos_out, depth);
    }
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    vec3 GetIndirectLighting_RSM(const in mat4 matShadowProjection[4], const in vec3 shadowViewPos, const in vec3 shadowViewNormal)
#else
    vec3 GetIndirectLighting_RSM(const in vec3 shadowViewPos, const in vec3 shadowViewNormal)
#endif
{
    vec3 shading = vec3(0.0);

    for (int i = 0; i < RSM_SAMPLE_COUNT; i++) {
        vec3 offsetShadowViewPos = shadowViewPos;

        //offsetShadowViewPos.xy += rsmPoissonDisk[i] * RSM_FILTER_SIZE;
        offsetShadowViewPos.xy += (hash23(vec3(gl_FragCoord.xy, i))*2.0 - 1.0) * RSM_FILTER_SIZE;

        vec2 uv;
        ivec2 iuv;
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            int cascade;
            float sampleDepth = GetNearestDepth(matShadowProjection, offsetShadowViewPos, uv, cascade).z;
            iuv = ivec2(uv * shadowMapSize);

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
            clipPos.z = texelFetch(shadowtex0, iuv, 0).r * 2.0 - 1.0;

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                clipPos.z *= 2.0;
            #endif

            vec3 samplePos = offsetShadowViewPos;
            samplePos.z = clipPos.z * shadowProjectionInverse[2][2] + shadowProjectionInverse[3][2];
        #endif

        uvec2 data = texelFetch(shadowcolor1, iuv, 0).rg;

        vec3 ray = samplePos - shadowViewPos;
        //ray.z *= 0.5;
        float rayLength = length(ray);
        vec3 rayDir = ray / rayLength;

        vec3 sampleNormal = unpackUnorm4x8(data.g).rgb;
        sampleNormal = normalize(sampleNormal * 2.0 - 1.0);

        vec3 sampleColor = unpackUnorm4x8(data.r).rgb;
        sampleColor = RGBToLinear(sampleColor);

        float NoR1 = max(dot(shadowViewNormal, rayDir), 0.0);
        float NoR2 = max(dot(sampleNormal, -rayDir), 0.0);

        sampleColor *= NoR1 * NoR2;
        //sampleColor *= pow(NoR1 * NoR2, 0.5);

        //float weight = dot(rsmPoissonDisk[i], rsmPoissonDisk[i]);
        //weight = max(1.0 - weight, 0.0) / length(ray);
        
        //float weight = 1.0 - saturate(pow2(rayLength) / (RSM_FILTER_SIZE));
        float weight = rcp(1.0 + rayLength*rayLength * RSM_FILTER_SIZE);
        //float weight = saturate(abs(ray.z) / RSM_FILTER_SIZE);

        shading += sampleColor * weight;
    }

    const float rsmIntensityF = RSM_INTENSITY * 0.01;
    return (shading / RSM_SAMPLE_COUNT) * rsmIntensityF * 20.0;
}
