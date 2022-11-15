vec3 GetScatteredLighting(const in float worldTraceHeight, const in vec2 skyLightLevels, const in vec2 scatteringF) {
    #ifdef RENDER_DEFERRED
        vec3 sunTransmittance = GetSunTransmittance(colortex7, worldTraceHeight, skyLightLevels.x);
        vec3 moonTransmittance = GetMoonTransmittance(colortex7, worldTraceHeight, skyLightLevels.y);
    #else
        vec3 sunTransmittance = GetSunTransmittance(colortex9, worldTraceHeight, skyLightLevels.x);
        vec3 moonTransmittance = GetMoonTransmittance(colortex9, worldTraceHeight, skyLightLevels.y);
    #endif

    vec3 sampleColor =
        scatteringF.x * sunTransmittance * sunColor * skyLightLevels.x +
        scatteringF.y * moonTransmittance * GetMoonPhaseLevel() * moonColor * skyLightLevels.y;

    sampleColor *= 1.0 - saturate((worldTraceHeight - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));

    return sampleColor;
}

vec3 GetVolumetricLighting(const in LightData lightData, const in vec3 viewNear, const in vec3 viewFar, const in vec2 scatteringF) {
    vec3 viewRayVector = viewFar - viewNear;
    float viewRayLength = length(viewRayVector);
    if (viewRayLength < EPSILON) return vec3(0.0);

    mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
    vec3 shadowViewStart = (matViewToShadowView * vec4(viewNear, 1.0)).xyz;
    vec3 shadowViewEnd = (matViewToShadowView * vec4(viewFar, 1.0)).xyz;

    vec3 shadowRayVector = shadowViewEnd - shadowViewStart;
    float shadowRayLength = length(shadowRayVector);

    vec3 rayDirection = shadowRayVector / shadowRayLength;
    float stepLength = shadowRayLength / (VL_SAMPLES_SKY + 1.0);
    vec3 rayStep = rayDirection * stepLength;
    vec3 accumColor = vec3(0.0);
    float accumF = 0.0;

    vec3 fogColorLinear = RGBToLinear(fogColor);

    float viewNearDist = length(viewNear);
    float viewStepLength = viewRayLength / (VL_SAMPLES_SKY + 1.0);

    float envFogStart = 0.0;
    float envFogEnd = min(fogEnd, far);
    const float envFogDensity = 0.4;

    #ifdef VL_DITHER
        shadowViewStart += rayStep * GetScreenBayerValue();
    #endif

    #ifdef SHADOW_CLOUD
        vec3 viewLightDir = normalize(shadowLightPosition);
        vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;
        //vec3 localPosFar = (gbufferModelViewInverse * vec4(viewFar, 1.0)).xyz;

        float cloudVis = 1.0 - GetCloudFactor(cameraPosition, localLightDir);
    #endif

    for (int i = 1; i <= VL_SAMPLES_SKY; i++) {
        vec3 currentShadowViewPos = shadowViewStart + i * rayStep;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowPos[4];
            for (int i = 0; i < 4; i++) {
                shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
            }

            // TODO
            //if (saturate(shadowPos.xy) != shadowPos.xy) continue;

            float sampleF = CompareNearestOpaqueDepth(shadowPos, lightData.shadowTilePos, lightData.shadowBias, vec2(0.0));
        #else
            vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                shadowPos.xyz = distort(shadowPos.xyz);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

            if (saturate(shadowPos.xy) != shadowPos.xy) continue;

            float sampleF = CompareOpaqueDepth(shadowPos, vec2(0.0), 0.0);
        #endif

        vec3 localTracePos = (shadowModelViewInverse * vec4(currentShadowViewPos, 1.0)).xyz;

        #ifdef SHADOW_CLOUD
            // when light is shining upwards
            if (localLightDir.y <= 0.0) {
                sampleF = 0.0;
            }
            // when light is shining downwards
            else {
                // when trace pos is below clouds, darken by cloud shadow
                if (cameraPosition.y + localTracePos.y < CLOUD_Y_LEVEL) {
                    sampleF *= 1.0 - GetCloudFactor(cameraPosition + localTracePos, localLightDir);
                }
                // only when camera is below clouds
                // when trace pos is above clouds, darken by visibility
                else if (cameraPosition.y < CLOUD_Y_LEVEL) {
                    sampleF *= cloudVis;
                }
            }
        #endif

        float worldTraceHeight = cameraPosition.y + localTracePos.y;
        vec3 sampleColor = GetScatteredLighting(worldTraceHeight, skyLightLevels, scatteringF);

        #ifdef SHADOW_COLOR
            if (sampleF > EPSILON) {
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    float transparentShadowDepth = GetNearestTransparentDepth(lightData, vec2(0.0), lightData.transparentShadowCascade);
                #else
                    float transparentShadowDepth = SampleTransparentDepth(shadowPos, vec2(0.0));
                #endif

                if (shadowPos.z - transparentShadowDepth >= EPSILON) {
                    vec3 shadowColor = GetShadowColor(shadowPos.xy);

                    if (all(greaterThan(shadowColor, vec3(EPSILON)))) shadowColor = vec3(1.0);
                    else shadowColor = normalize(shadowColor) * 2.0;

                    sampleColor *= shadowColor;
                }
            }
        #endif

        // float traceViewDist = viewNearDist + i * viewStepLength;
        // float fogF = GetFogFactor(traceViewDist, envFogStart, envFogEnd, envFogDensity);
        // sampleF *= fogF;

        // vec3 traceViewPos = viewNear + i * viewStep;
        // float fogF = GetVanillaFogFactor(traceViewPos);
        // sampleColor *= mix(vec3(1.0), fogColorLinear, fogF);

        accumColor += sampleF * sampleColor;
    }

    float traceLength = min(viewRayLength / min(far, fogEnd), 1.0);

    return (accumColor / VL_SAMPLES_SKY) * traceLength;
}

vec3 GetWaterVolumetricLighting(const in LightData lightData, const in vec3 nearViewPos, const in vec3 farViewPos, const in vec2 scatteringF) {
    #ifdef SHADOW_CLOUD
        vec3 viewLightDir = normalize(shadowLightPosition);
        vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;

        //vec3 upDir = normalize(upPosition);
        //float horizonFogF = 1.0 - abs(dot(viewLightDir, upDir));

        if (localLightDir.y <= 0.0) return vec3(0.0);
    #endif

    mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
    vec3 shadowViewStart = (matViewToShadowView * vec4(nearViewPos, 1.0)).xyz;
    vec3 shadowViewEnd = (matViewToShadowView * vec4(farViewPos, 1.0)).xyz;

    vec3 shadowRayVector = shadowViewEnd - shadowViewStart;
    float shadowRayLength = length(shadowRayVector);
    vec3 rayDirection = shadowRayVector / shadowRayLength;

    float stepLength = shadowRayLength / (VL_SAMPLES_WATER + 1.0);
    vec3 rayStep = rayDirection * stepLength;
    vec3 accumF = vec3(0.0);
    float lightSample, transparentDepth;

    vec3 viewRayVector = farViewPos - nearViewPos;
    vec3 viewStep = viewRayVector / (VL_SAMPLES_WATER + 1.0);
    float viewRayLength = length(viewRayVector);
    float viewStepLength = viewRayLength / (VL_SAMPLES_WATER + 1.0);

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

    vec3 extinctionInv = (1.0 - waterAbsorbColor) * WATER_ABSROPTION_RATE;

    for (int i = 1; i <= VL_SAMPLES_WATER; i++) {
        vec3 currentShadowViewPos = shadowViewStart + i * rayStep;
        transparentDepth = 1.0;

        vec3 waterShadowPos;
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowPos[4];
            for (int i = 0; i < 4; i++) {
                shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
            }

            // TODO
            //if (saturate(shadowPos.xy) != shadowPos.xy) continue;

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

            if (saturate(shadowPos.xy) != shadowPos.xy) continue;

            lightSample = CompareOpaqueDepth(shadowPos, vec2(0.0), 0.0);

            if (lightSample > EPSILON)
                transparentDepth = SampleTransparentDepth(shadowPos, vec2(0.0));

            waterShadowPos = shadowPos.xyz;
        #endif

        vec3 localTracePos = (shadowModelViewInverse * vec4(currentShadowViewPos, 1.0)).xyz;

        #ifdef SHADOW_CLOUD
            // when light is shining upwards
            // if (localLightDir.y <= 0.0) {
            //     lightSample = 0.0;
            // }
            // when light is shining downwards
            //else {
                // when trace pos is below clouds, darken by cloud shadow
                if (cameraPosition.y + localTracePos.y < CLOUD_Y_LEVEL) {
                    lightSample *= 1.0 - GetCloudFactor(cameraPosition + localTracePos, localLightDir);
                }
            //}
        #endif

        float waterLightDist = max((waterShadowPos.z - transparentDepth) * MaxShadowDist, 0.0);
        waterLightDist += i * viewStepLength;

        float worldTraceHeight = cameraPosition.y + localTracePos.y;
        vec3 lightColor = GetScatteredLighting(worldTraceHeight, skyLightLevels, scatteringF);
        lightColor *= exp(-waterLightDist * extinctionInv);

        // sample normal, get fresnel, darken
        uint data = textureLod(shadowcolor1, waterShadowPos.xy, 0).g;
        vec3 normal = unpackUnorm4x8(data).xyz;
        normal = normalize(normal * 2.0 - 1.0);
        float NoL = max(normal.z, 0.0);
        float waterF = F_schlick(NoL, 0.02, 1.0);

        accumF += lightSample * lightColor * max(1.0 - waterF, 0.0);
    }

    float traceLength = saturate(viewRayLength / waterFogDistSmooth);
    return (accumF / VL_SAMPLES_WATER) * traceLength;
}
