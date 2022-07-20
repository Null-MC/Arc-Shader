float GetVolumtricFactor(const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
    vec3 rayVector = shadowViewEnd - shadowViewStart;
    float rayLength = length(rayVector);

    vec3 rayDirection = rayVector / rayLength;
    float stepLength = rayLength / VL_SAMPLE_COUNT;
    float accumF = 0.0;

    for (int i = 1; i <= VL_SAMPLE_COUNT; i++) {
        vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;

        #if SHADOW_TYPE == 3
            // TODO: create 4 CSM projection matrices

            accumF += CompareNearestDepth(shadowPos);
        #else
            vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

            #if SHADOW_TYPE == 2
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
            accumF += CompareDepth(shadowPos, vec2(0.0));
        #endif
    }

    //return accumF / VL_SAMPLE_COUNT;
    return smoothstep(0.0, 1.0, accumF / VL_SAMPLE_COUNT);
}

float GetVolumtricLighting(const in vec3 shadowViewStart, const in vec3 shadowViewEnd, const in float G_scattering) {
    vec3 rayDirection = normalize(shadowViewEnd - shadowViewStart);
    const vec3 sunDirection = vec3(0.0, 0.0, 1.0);

    float VoL = dot(rayDirection, sunDirection);
    //if (VoL < 0.0) return 0.0;

    float scattering = ComputeVolumetricScattering(VoL, G_scattering);

    return GetVolumtricFactor(shadowViewStart, shadowViewEnd) * scattering;
}
