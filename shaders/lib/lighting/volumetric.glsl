#define VL_SAMPLE_COUNT 100
#define VL_G_SCATTERING 0.9

float ComputeVolumetricScattering(const in float VoL) {
    const float G_scattering2 = VL_G_SCATTERING * VL_G_SCATTERING;

    return (1.0 - G_scattering2) / (4.0 * PI * pow(1.0 + G_scattering2 - (2.0 * VL_G_SCATTERING) * VoL, 1.5));
}

float GetVolumtricFactor(const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
    vec3 rayVector = shadowViewEnd - shadowViewStart;
    float rayLength = length(rayVector);

    vec3 rayDirection = rayVector / rayLength;
    float stepLength = rayLength / VL_SAMPLE_COUNT;
    float accumF = 0.0;

    for (int i = 1; i <= VL_SAMPLE_COUNT; i++) {
        vec3 currentShadowViewPos = shadowViewStart + i * rayDirection * stepLength;
        vec3 shadowPos = (shadowProjection * vec4(currentShadowViewPos, 1.0)).xyz;

        #if SHADOW_TYPE == 2
            float distortFactor = getDistortFactor(shadowPos.xy);
            shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
        #endif

        shadowPos = shadowPos * 0.5 + 0.5;

        #ifdef SHADOW_ENABLE_HWCOMP
            #ifndef IS_OPTIFINE
                float shadowDepth = textureLod(shadowtex1HW, shadowPos, 0);
                accumF += step(0.5, shadowDepth);
            #else
                float shadowDepth = textureLod(shadowtex1, shadowPos, 0);
                accumF += step(0.5, shadowDepth);
            #endif
        #else
            float shadowDepth = textureLod(shadowtex1, shadowPos.xy, 0).r;
            accumF += step(shadowPos.z + EPSILON, shadowDepth);
        #endif
    }

    //return accumF / VL_SAMPLE_COUNT;
    return smoothstep(0.0, 1.0, accumF / VL_SAMPLE_COUNT);
}

float GetVolumtricLighting(const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
    vec3 rayDirection = normalize(shadowViewEnd - shadowViewStart);
    const vec3 sunDirection = vec3(0.0, 0.0, 1.0);

    float VoL = dot(rayDirection, sunDirection);
    //if (VoL < 0.0) return 0.0;

    float scattering = ComputeVolumetricScattering(VoL);

    return GetVolumtricFactor(shadowViewStart, shadowViewEnd) * scattering;
}
