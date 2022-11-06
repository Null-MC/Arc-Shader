#ifdef SHADOW_COLOR
    vec3 GetVolumetricColor(LightData lightData, const in vec3 shadowViewStart, const in vec3 shadowViewEnd) {
        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / (VL_SAMPLE_COUNT + 1.0);
        vec3 rayStep = rayDirection * stepLength;
        vec3 accumCol = vec3(0.0);
        float accumF = 0.0;

        #ifdef VL_DITHER
            vec3 ditherOffset = rayStep * GetScreenBayerValue();
        #endif

        for (int i = 1; i <= VL_SAMPLE_COUNT; i++) {
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
    vec3 GetVolumetricFactor(const in LightData lightData, const in vec3 viewNear, const in vec3 viewFar, const in vec3 lightColor) {
        mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
        vec3 shadowViewStart = (matViewToShadowView * vec4(viewNear, 1.0)).xyz;
        vec3 shadowViewEnd = (matViewToShadowView * vec4(viewFar, 1.0)).xyz;

        vec3 rayVector = shadowViewEnd - shadowViewStart;
        float rayLength = length(rayVector);

        vec3 rayDirection = rayVector / rayLength;
        float stepLength = rayLength / (VL_SAMPLE_COUNT + 1.0);
        vec3 rayStep = rayDirection * stepLength;
        //float accumF = 0.0;
        vec3 accumColor = vec3(0.0);

        vec3 fogColorLinear = RGBToLinear(fogColor);

        vec3 viewStep = (viewFar - viewNear) / (VL_SAMPLE_COUNT + 1.0);

        #ifdef VL_DITHER
            shadowViewStart += rayStep * GetScreenBayerValue();
        #endif

        for (int i = 1; i <= VL_SAMPLE_COUNT; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayStep;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                for (int i = 0; i < 4; i++) {
                    shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    shadowPos[i].xy = shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
                }

                float sampleF = CompareNearestOpaqueDepth(shadowPos, lightData.shadowTilePos, lightData.shadowBias, vec2(0.0));
            #else
                vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    shadowPos.xyz = distort(shadowPos.xyz);
                #endif

                shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

                float sampleF = CompareOpaqueDepth(shadowPos, vec2(0.0), 0.0);
            #endif

            vec3 traceViewPos = viewNear + i * viewStep;
            float fogF = saturate(length(traceViewPos) / min(fogEnd, far)); //GetVanillaFogFactor(traceViewPos);
            vec3 sampleColor = lightColor * mix(vec3(1.0), fogColorLinear, fogF);

            accumColor += sampleF * sampleColor;
        }

        return accumColor / VL_SAMPLE_COUNT;
    }
#endif

#ifdef SHADOW_COLOR
    vec3 GetVolumetricLightingColor(const in LightData lightData, const in vec3 viewNear, const in vec3 viewFar, const in vec3 lightColor) {
        float rayLen = min(length(viewFar - viewNear) / min(far, fogEnd), 1.0);
        return GetVolumetricColor(lightData, viewNear, viewFar, lightColor) * rayLen;
    }
#else
    vec3 GetVolumetricLighting(const in LightData lightData, const in vec3 viewNear, const in vec3 viewFar, const in vec3 lightColor) {
        float rayLen = min(length(viewFar - viewNear) / min(far, fogEnd), 1.0);
        return GetVolumetricFactor(lightData, viewNear, viewFar, lightColor) * rayLen;
    }
#endif

vec3 GetWaterVolumetricLighting(const in LightData lightData, const in vec3 nearViewPos, const in vec3 farViewPos, const in vec3 lightColor) {
    mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
    vec3 shadowViewStart = (matViewToShadowView * vec4(nearViewPos, 1.0)).xyz;
    vec3 shadowViewEnd = (matViewToShadowView * vec4(farViewPos, 1.0)).xyz;

    vec3 rayVector = shadowViewEnd - shadowViewStart;
    float shadowRayLength = length(rayVector);
    vec3 rayDirection = rayVector / shadowRayLength;

    float stepLength = shadowRayLength / (VL_SAMPLE_COUNT + 1.0);
    vec3 rayStep = rayDirection * stepLength;
    vec3 accumF = vec3(0.0);
    float lightSample, transparentDepth;

    vec3 viewRayVector = farViewPos - nearViewPos;
    float viewRayLength = length(rayVector);
    vec3 viewStep = viewRayVector / (VL_SAMPLE_COUNT + 1.0);

    #ifdef VL_DITHER
        shadowViewStart += rayStep * GetScreenBayerValue();
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        float MaxShadowDist = far * 3.0;
    #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
        const float MaxShadowDist = 512.0;
    #else
        const float MaxShadowDist = 256.0;
    #endif

    for (int i = 1; i <= VL_SAMPLE_COUNT; i++) {
        vec3 currentShadowViewPos = shadowViewStart + i * rayStep;
        transparentDepth = 1.0;

        vec3 waterShadowPos;
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowPos[4];
            for (int i = 0; i < 4; i++) {
                shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
            }

            lightSample = CompareNearestOpaqueDepth(shadowPos, lightData.shadowTilePos, lightData.shadowBias, vec2(0.0));

            int waterOpaqueCascade = -1;
            if (lightSample > EPSILON)
                transparentDepth = GetNearestTransparentDepth(shadowPos, lightData.shadowTilePos, vec2(0.0), waterOpaqueCascade);

            waterShadowPos = waterOpaqueCascade >= 0
                ? shadowPos[waterOpaqueCascade]
                : currentShadowViewPos;
        #else
            vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                shadowPos.xyz = distort(shadowPos.xyz);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

            lightSample = CompareOpaqueDepth(shadowPos, vec2(0.0), 0.0);

            if (lightSample > EPSILON)
                transparentDepth = SampleTransparentDepth(shadowPos, vec2(0.0));

            waterShadowPos = shadowPos.xyz;
        #endif

        // sample normal, get fresnel, darken
        uint data = textureLod(shadowcolor1, waterShadowPos.xy, 0).g;
        vec3 normal = unpackUnorm4x8(data).xyz * 2.0 - 1.0;
        normal = normalize(normal);
        //vec3 normal = RestoreNormalZ(normalXY) * 0.5 + 0.5;

        vec3 lightDir = vec3(0.0, 0.0, 1.0);//normalize(shadowLightPosition);
        float NoL = max(dot(normal, lightDir), 0.0);
        float waterF = F_schlick(NoL, 0.02, 1.0);

        float waterLightDist = max((waterShadowPos.z - transparentDepth) * MaxShadowDist, 0.0);

        vec3 traceViewPos = nearViewPos + i * viewStep;
        float traceDist = length(traceViewPos.z);
        waterLightDist += traceDist;

        const vec3 extinctionInv = 1.0 - WATER_ABSORB_COLOR;
        vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterLightDist * extinctionInv);

        float invF = max(1.0 - waterF, 0.0);
        accumF += lightSample * invF * lightColor * absorption;
    }

    return (accumF / VL_SAMPLE_COUNT) * (viewRayLength / (2.0 * WATER_FOG_DIST));
}
