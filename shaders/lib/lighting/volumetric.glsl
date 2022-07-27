float GetVolumetricFactor(const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float shadowBias) {
    vec3 rayVector = shadowViewEnd - shadowViewStart;
    float rayLength = length(rayVector);

    vec3 rayDirection = rayVector / rayLength;
    float stepLength = rayLength / VL_SAMPLE_COUNT;
    float accumF = 0.0;

    for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
        vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            // TODO: create 4 CSM projection matrices

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
    const vec3 sunDirection = vec3(0.0, 0.0, 1.0);
    vec3 rayDirection = normalize(shadowViewEnd - shadowViewStart);
    float VoL = dot(rayDirection, sunDirection);

    float scattering = ComputeVolumetricScattering(VoL, G_scattering);
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
                // TODO: create 4 CSM projection matrices

                float depthSample = CompareNearestDepth(shadowPos, vec2(0.0));

                if (depthSample > EPSILON)
                    accumCol += CompareNearestColor(shadowPos.xyz) * depthSample;
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
        const vec3 sunDirection = vec3(0.0, 0.0, 1.0);
        vec3 rayDirection = normalize(shadowViewEnd - shadowViewStart);
        float VoL = dot(rayDirection, sunDirection);

        float scattering = ComputeVolumetricScattering(VoL, G_scattering);
        //if (scattering < 0.0001) return vec3(0.0);

        return GetVolumetricColor(shadowViewStart, shadowViewEnd, shadowBias) * scattering;
    }
#endif
