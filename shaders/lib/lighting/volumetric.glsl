float GetVolumetricFactor(const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float shadowBias) {
    vec3 rayVector = shadowViewEnd - shadowViewStart;
    float rayLength = length(rayVector);

    vec3 rayDirection = rayVector / rayLength;
    float stepLength = rayLength / VL_SAMPLE_COUNT;
    float accumF = 0.0;

    for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
        vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowPos[4];
            for (int i = 0; i < 4; i++) {
                shadowPos[i] = (matShadowProjections[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                
                vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;
            }

            accumF += CompareNearestDepth(shadowPos, vec2(0.0));
        #else
            vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
            accumF += CompareDepth(shadowPos, vec2(0.0), shadowBias);
        #endif
    }

    return accumF / VL_SAMPLE_COUNT;
    //return smoothstep(0.0, 1.0, accumF / VL_SAMPLE_COUNT);
}

float GetVolumetricLighting(const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float shadowBias, const in float G_scattering) {
    vec3 ray = shadowViewEnd - shadowViewStart;
    vec3 rayDir = normalize(ray);
    float rayLen = min(length(ray) / (101.0 - VL_STRENGTH), 1.0);

    const vec3 sunDir = vec3(0.0, 0.0, 1.0);
    float VoL = dot(rayDir, sunDir);

    float scattering = ComputeVolumetricScattering(VoL, G_scattering) * rayLen;
    if (scattering < EPSILON) return 0.0;

    return GetVolumetricFactor(shadowViewStart, shadowViewEnd, shadowBias) * scattering;
}

#ifdef SHADOW_COLOR
    vec3 GetVolumetricColor(const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float shadowBias) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / VL_SAMPLE_COUNT;
        vec3 accumCol = vec3(0.0);

        for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                for (int i = 0; i < 4; i++)
                    shadowPos[i] = (matShadowProjections[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;

                float depthSample = CompareNearestDepth(shadowPos, vec2(0.0));

                if (depthSample > EPSILON) {
                    vec3 shadowColor = GetShadowColor(shadowPos);
                    accumCol += RGBToLinear(shadowColor) * depthSample;
                }
            #else
                vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    float distortFactor = getDistortFactor(shadowPos.xy);
                    shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
                #endif

                shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
                float depthSample = CompareDepth(shadowPos, vec2(0.0), shadowBias);

                if (depthSample > EPSILON) {
                    vec3 shadowColor = GetShadowColor(shadowPos.xyz, -shadowBias);
                    accumCol += RGBToLinear(shadowColor) * depthSample;
                }
            #endif
        }

        return accumCol / VL_SAMPLE_COUNT;
        //return smoothstep(0.0, 1.0, accumCol / VL_SAMPLE_COUNT);
    }

    vec3 GetVolumetricLightingColor(const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float shadowBias, const in float G_scattering) {
        vec3 ray = shadowViewEnd - shadowViewStart;
        vec3 rayDir = normalize(ray);
        float rayLen = min(length(ray) / (101.0 - VL_STRENGTH), 1.0);

        const vec3 sunDir = vec3(0.0, 0.0, 1.0);
        float VoL = dot(rayDir, sunDir);

        float scattering = ComputeVolumetricScattering(VoL, G_scattering) * rayLen;
        if (scattering < EPSILON) return vec3(0.0);

        return GetVolumetricColor(shadowViewStart, shadowViewEnd, shadowBias) * scattering;
    }
#endif
