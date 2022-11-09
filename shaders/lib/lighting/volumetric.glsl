vec3 GetVolumetricFactor(const in LightData lightData, const in vec3 viewNear, const in vec3 viewFar, const in vec3 lightColor) {
    mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
    vec3 shadowViewStart = (matViewToShadowView * vec4(viewNear, 1.0)).xyz;
    vec3 shadowViewEnd = (matViewToShadowView * vec4(viewFar, 1.0)).xyz;

    vec3 rayVector = shadowViewEnd - shadowViewStart;
    float rayLength = length(rayVector);
    if (rayLength < EPSILON) return vec3(0.0);

    vec3 rayDirection = rayVector / rayLength;
    float stepLength = rayLength / (VL_SAMPLE_COUNT + 1.0);
    vec3 rayStep = rayDirection * stepLength;
    vec3 accumColor = vec3(0.0);
    float accumF = 0.0;

    vec3 fogColorLinear = RGBToLinear(fogColor);

    vec3 viewStep = (viewFar - viewNear) / (VL_SAMPLE_COUNT + 1.0);

    #ifdef VL_DITHER
        shadowViewStart += rayStep * GetScreenBayerValue();
    #endif

    #ifdef SHADOW_CLOUD
        vec3 viewLightDir = normalize(shadowLightPosition);
        vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;

        vec3 upDir = normalize(upPosition);
        float horizonFogF = 1.0 - abs(dot(viewLightDir, upDir));

        vec3 localPos = (gbufferModelViewInverse * vec4(viewFar, 1.0)).xyz;
        float cloudVis = GetCloudFactor(cameraPosition + localPos, localLightDir);
        cloudVis = mix(cloudVis, 1.0, horizonFogF);
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

        #ifdef SHADOW_CLOUD
            // when light is shining upwards
            if (localLightDir.y <= 0.0) {
                sampleF = 0.0;
            }
            // when light is shining downwards
            else {
                vec3 localPos = (shadowModelViewInverse * vec4(currentShadowViewPos, 1.0)).xyz;

                float cloudF;
                // when trace pos is below clouds, darken by cloud shadow
                if (cameraPosition.y + localPos.y < CLOUD_PLANE_Y_LEVEL) {
                    cloudF = GetCloudFactor(cameraPosition + localPos, localLightDir);

                    float horizonFogF = 1.0 - max(localLightDir.y, 0.0);
                    cloudF = mix(cloudF, 1.0, horizonFogF);
                }
                // only when camera is below clouds
                // when trace pos is above clouds, darken by visibility
                else if (cameraPosition.y < CLOUD_PLANE_Y_LEVEL) {
                    cloudF = cloudVis;
                }

                sampleF *= 1.0 - cloudF;
            }
        #endif

        vec3 sampleColor = lightColor;

        #ifdef SHADOW_COLOR
            if (sampleF > EPSILON) {
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    float transparentShadowDepth = GetNearestTransparentDepth(lightData, vec2(0.0), lightData.transparentShadowCascade);
                #else
                    float transparentShadowDepth = SampleTransparentDepth(shadowPos, vec2(0.0));
                #endif

                if (shadowPos.z - transparentShadowDepth >= EPSILON) {
                    vec3 shadowColor = GetShadowColor(shadowPos.xy);

                    if (dot(shadowColor, shadowColor) < EPSILON) shadowColor = vec3(1.0);
                    else shadowColor = normalize(shadowColor) * 2.0;

                    sampleColor *= shadowColor;
                }
            }
        #endif

        vec3 traceViewPos = viewNear + i * viewStep;
        float fogF = saturate(length(traceViewPos) / min(fogEnd, far)); //GetVanillaFogFactor(traceViewPos);
        sampleColor *= mix(vec3(1.0), fogColorLinear, fogF);

        accumColor += sampleF * sampleColor;
    }

    //accumF += sampleF;

    return accumColor / VL_SAMPLE_COUNT;
}

vec3 GetVolumetricLighting(const in LightData lightData, const in vec3 viewNear, const in vec3 viewFar, const in vec3 lightColor) {
    float rayLen = min(length(viewFar - viewNear) / min(far, fogEnd), 1.0);
    return GetVolumetricFactor(lightData, viewNear, viewFar, lightColor) * rayLen;
}

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

    #ifdef SHADOW_CLOUD
        vec3 viewLightDir = normalize(shadowLightPosition);
        vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;

        vec3 upDir = normalize(upPosition);
        float horizonFogF = 1.0 - abs(dot(viewLightDir, upDir));
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

        #ifdef SHADOW_CLOUD
            // when light is shining upwards
            if (localLightDir.y <= 0.0) {
                lightSample = 0.0;
            }
            // when light is shining downwards
            else {
                vec3 localPos = (shadowModelViewInverse * vec4(currentShadowViewPos, 1.0)).xyz;

                // when trace pos is below clouds, darken by cloud shadow
                if (cameraPosition.y + localPos.y < CLOUD_PLANE_Y_LEVEL) {
                    float cloudF = GetCloudFactor(cameraPosition + localPos, localLightDir);

                    float horizonFogF = 1.0 - max(dot(localLightDir, vec3(0.0, 1.0, 0.0)), 0.0);
                    cloudF = mix(cloudF, 1.0, horizonFogF);

                    lightSample *= 1.0 - cloudF;
                }
            }
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
