#ifdef SHADOW_COLOR
    vec3 GetVolumetricColor(LightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / VL_SAMPLE_COUNT;
        vec3 rayStep = rayDirection * stepLength;
        vec3 accumCol = vec3(0.0);
        float accumF = 0.0;

        #ifdef VL_DITHER
            vec3 ditherOffset = rayStep * GetScreenBayerValue();
        #endif

        for (int i = 1; i < VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayStep;

            #ifdef VL_DITHER
                currentShadowViewPos += ditherOffset;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                for (int i = 0; i < 4; i++) {
                    lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
                }

                float depthSample = CompareNearestOpaqueDepth(lightData, vec2(0.0));
            #else
                lightData.shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz);
                #endif

                lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;

                float depthSample = CompareOpaqueDepth(lightData.shadowPos, vec2(0.0), 0.0);
            #endif

            accumF += depthSample;

            if (depthSample > EPSILON) {
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData, vec2(0.0), lightData.transparentShadowCascade);
                #else
                    lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos, vec2(0.0));
                #endif

                vec3 shadowColor = GetShadowColor(lightData);
                if (dot(shadowColor, shadowColor) > EPSILON) {
                    shadowColor = RGBToLinear(shadowColor);
                    accumCol += normalize(shadowColor);// * depthSample;
                }
            }
        }

        if (dot(accumCol, accumCol) > EPSILON) accumCol = normalize(accumCol)*2.0;

        return vec3(accumF / VL_SAMPLE_COUNT) * accumCol;
    }
#else
    float GetVolumetricFactor(LightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / VL_SAMPLE_COUNT;
        vec3 rayStep = rayDirection * stepLength;
        float accumF = 0.0;

        vec3 rayStart = shadowViewStart;

        #ifdef VL_DITHER
            rayStart += rayStep * GetScreenBayerValue();
        #endif

        for (int i = 1; i <= VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = rayStart + i * rayStep;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                //vec3 shadowPos[4];
                for (int i = 0; i < 4; i++) {
                    lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
                }

                accumF += CompareNearestOpaqueDepth(lightData, vec2(0.0));
            #else
                lightData.shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz);
                #endif

                lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;

                accumF += CompareOpaqueDepth(lightData.shadowPos, vec2(0.0), 0.0);
            #endif
        }

        return accumF / VL_SAMPLE_COUNT;
    }
#endif

#ifdef SHADOW_COLOR
    vec3 GetVolumetricLightingColor(const in LightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        float rayLen = min(length(shadowViewEnd - shadowViewStart) / far, 1.0);
        return GetVolumetricColor(lightData, shadowViewStart, shadowViewEnd) * rayLen;
    }
#else
    float GetVolumetricLighting(const in LightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        float rayLen = min(length(shadowViewEnd - shadowViewStart) / far, 1.0);
        return GetVolumetricFactor(lightData, shadowViewStart, shadowViewEnd) * rayLen;
    }
#endif

vec3 GetWaterVolumetricLighting(const in LightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
    //return GetVolumetricFactor(lightData, shadowViewStart, shadowViewEnd) * rayLen;

    vec3 rayVector = shadowViewEnd - shadowViewStart;
    float rayLength = length(rayVector);
    vec3 rayDirection = rayVector / rayLength;

    if (rayLength > WATER_FOG_DIST) {
        rayVector = rayDirection * WATER_FOG_DIST;
        rayLength = WATER_FOG_DIST;
    }

    //const float maxStep = WATER_FOG_DIST / VL_SAMPLE_COUNT;
    int stepCount = max(int(ceil(rayLength / WATER_FOG_DIST * VL_SAMPLE_COUNT)), 1);

    float stepLength = rayLength / stepCount;
    vec3 rayStep = rayDirection * stepLength;
    vec3 accumF = vec3(0.0);
    float lightSample, transparentDepth;

    vec3 rayStart = shadowViewStart;

    #ifdef VL_DITHER
        rayStart += rayStep * GetScreenBayerValue();
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        const float MaxShadowDist = far * 3.0;
    #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
        const float MaxShadowDist = 512.0;
    #else
        const float MaxShadowDist = 256.0;
    #endif

    for (int i = 1; i <= stepCount; i++) {
        vec3 currentShadowViewPos = rayStart + i * rayStep;
        transparentDepth = 1.0;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowPos[4];
            for (int i = 0; i < 4; i++) {
                shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
            }

            lightSample = CompareNearestOpaqueDepth(shadowPos, lightData.shadowTilePos, vec2(0.0));

            if (lightSample > EPSILON)
                transparentDepth = SampleTransparentDepth(shadowPos, vec2(0.0));
        #else
            vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                shadowPos.xyz = distort(shadowPos.xyz);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

            lightSample = CompareOpaqueDepth(shadowPos, vec2(0.0), 0.0);

            if (lightSample > EPSILON)
                transparentDepth = SampleTransparentDepth(shadowPos, vec2(0.0));
        #endif

        // TODO: apply absorption to each step depending on the distance travelled so far
        float waterLightDist = max((shadowPos.z - transparentDepth) * MaxShadowDist, 0.0);
        waterLightDist = min(waterLightDist, WATER_FOG_DIST);

        const vec3 extinctionInv = 1.0 - WATER_ABSORB_COLOR;
        vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterLightDist * extinctionInv);

        accumF += lightSample * absorption;
    }

    return (accumF / stepCount);// * min(rayLength / WATER_FOG_DIST, 1.0);
}
