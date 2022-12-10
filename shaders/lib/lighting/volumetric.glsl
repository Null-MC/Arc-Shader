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

    // float heightExt = saturate((worldTraceHeight - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));

    return sampleColor;// * (1.0 - pow2(heightExt));
}

vec3 GetVolumetricLighting(const in LightData lightData, inout float extinction, const in vec3 viewNear, const in vec3 viewFar, const in vec2 scatteringF) {
    vec3 viewRayVector = viewFar - viewNear;
    float viewRayLength = length(viewRayVector);
    if (viewRayLength < EPSILON) return vec3(0.0);

    mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
    vec3 shadowViewStart = (matViewToShadowView * vec4(viewNear, 1.0)).xyz;
    vec3 shadowViewEnd = (matViewToShadowView * vec4(viewFar, 1.0)).xyz;

    vec3 shadowRayVector = shadowViewEnd - shadowViewStart;
    float shadowRayLength = length(shadowRayVector);
    const float stepF = rcp(VL_SAMPLES_SKY + 1.0);

    vec3 rayDirection = shadowRayVector / shadowRayLength;
    float stepLength = shadowRayLength * stepF;
    vec3 rayStep = rayDirection * stepLength;
    vec3 accumColor = vec3(0.0);
    //float accumExt = 1.0;
    float accumF = 0.0;

    vec3 fogColorLinear = RGBToLinear(fogColor);

    float viewNearDist = length(viewNear);
    float viewStepLength = viewRayLength * stepF;

    float envFogStart = 0.0;
    float envFogEnd = min(far, gl_Fog.end);
    const float envFogDensity = 0.4;

    #ifdef VL_DITHER
        shadowViewStart += rayStep * GetScreenBayerValue();
    #endif

    #ifdef SHADOW_CLOUD
        vec3 viewLightDir = normalize(shadowLightPosition);
        vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;
        //vec3 localPosFar = (gbufferModelViewInverse * vec4(viewFar, 1.0)).xyz;

        if (localLightDir.y <= 0.0) return vec3(0.0);

        //float cloudVis = 1.0 - GetCloudFactor(cameraPosition, localLightDir);
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
        vec3 worldTracePos = cameraPosition + localTracePos;

        #ifdef SHADOW_CLOUD
            // when light is shining upwards
            //if (localLightDir.y <= 0.0) {
            //    sampleF = 0.0;
            //}
            // when light is shining downwards
            //else {
                // when trace pos is below clouds, darken by cloud shadow
                if (worldTracePos.y < CLOUD_Y_LEVEL) {
                    sampleF *= 1.0 - GetCloudFactor(worldTracePos, localLightDir);
                }
                // only when camera is below clouds
                // when trace pos is above clouds, darken by visibility
                else if (cameraPosition.y < CLOUD_Y_LEVEL) {
                    sampleF *= 1.0 - GetCloudFactor(worldTracePos, localLightDir);
                }
            //}
        #endif

        if (sampleF < EPSILON) continue;

        //float worldTraceHeight = cameraPosition.y + localTracePos.y;
        vec3 sampleColor = GetScatteredLighting(worldTracePos.y, skyLightLevels, scatteringF);
        float sampleDensity = 1.0 - saturate((worldTracePos.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));

        #ifdef SHADOW_COLOR
            //if (sampleF > EPSILON) {
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    float transparentShadowDepth = GetNearestTransparentDepth(lightData, vec2(0.0), lightData.transparentShadowCascade);
                #else
                    float transparentShadowDepth = SampleTransparentDepth(shadowPos, vec2(0.0));
                #endif

                if (shadowPos.z - transparentShadowDepth >= EPSILON) {
                    vec3 shadowColor = GetShadowColor(shadowPos.xy);

                    if (!any(greaterThan(shadowColor, vec3(EPSILON)))) shadowColor = vec3(1.0);
                    shadowColor = normalize(shadowColor) * 2.0;

                    sampleColor *= shadowColor;
                }
            //}
        #endif

        #ifdef VL_SKY_NOISE
            float texDensity1 = texture(colortex13, worldTracePos / 256.0).r;
            float texDensity2 = texture(colortex13, worldTracePos / 44.0).r;
            float texDensity = 1.0 - 0.3 * texDensity1 - 0.15 * texDensity2;
            sampleDensity *= texDensity;

            float stepExt = exp(-ATMOS_EXTINCTION * viewStepLength * sampleDensity);
            //extinction *= 1.0 - (1.0 - stepExt) * stepF;
            extinction *= stepExt;

            sampleF *= sampleDensity;
        #else
            float traceViewDist = viewNearDist + i * viewStepLength;
            sampleF *= exp(-ATMOS_EXTINCTION * traceViewDist);
        #endif

        accumColor += sampleF * sampleColor;
    }

    //float traceLength = min(viewRayLength / min(far, gl_Fog.end), 1.0);

    return (accumColor / VL_SAMPLES_SKY) * viewRayLength * VL_SKY_DENSITY;
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
        vec3 localTracePos = (shadowModelViewInverse * vec4(currentShadowViewPos, 1.0)).xyz;
        vec3 worldTracePos = cameraPosition + localTracePos;
        //float worldTraceHeight = cameraPosition.y + localTracePos.y;
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

            // if (saturate(shadowPos.xy) != shadowPos.xy) {
            //     vec3 lightColor2 = GetScatteredLighting(worldTraceHeight, skyLightLevels, scatteringF);
            //     accumF += lightColor2 * 10000.0;// * exp(-(i * viewStepLength) * extinctionInv);
            //     return vec3(10000.0, 0.0, 0.0);
            // }

            lightSample = CompareOpaqueDepth(shadowPos, vec2(0.0), 0.0);

            if (lightSample > EPSILON)
                transparentDepth = SampleTransparentDepth(shadowPos, vec2(0.0));

            waterShadowPos = shadowPos.xyz;
        #endif

        #ifdef SHADOW_CLOUD
            // when light is shining upwards
            // if (localLightDir.y <= 0.0) {
            //     lightSample = 0.0;
            // }
            // when light is shining downwards
            //else {
                // when trace pos is below clouds, darken by cloud shadow
                if (worldTracePos.y < CLOUD_Y_LEVEL) {
                    lightSample *= 1.0 - GetCloudFactor(worldTracePos, localLightDir);
                }
            //}
        #endif

        float waterLightDist = max((waterShadowPos.z - transparentDepth) * MaxShadowDist, 0.0);
        waterLightDist += i * viewStepLength;

        vec3 lightColor = GetScatteredLighting(worldTracePos.y, skyLightLevels, scatteringF);
        lightColor *= exp(-waterLightDist * extinctionInv);

        // sample normal, get fresnel, darken
        uint data = textureLod(shadowcolor1, waterShadowPos.xy, 0).g;
        vec3 normal = unpackUnorm4x8(data).xyz;
        normal = normalize(normal * 2.0 - 1.0);
        float NoL = max(normal.z, 0.0);
        float waterF = F_schlick(NoL, 0.02, 1.0);

        #ifdef VL_WATER_NOISE
            float sampleDensity1 = texture(colortex13, worldTracePos / 96.0).r;
            float sampleDensity2 = texture(colortex13, worldTracePos / 16.0).r;
            lightSample *= saturate((1.0 - 0.6 * sampleDensity1) + 0.4 * sampleDensity2);
        #endif

        accumF += lightSample * lightColor * max(1.0 - waterF, 0.0);
    }

    //float traceLength = saturate(viewRayLength / far);
    return (accumF / VL_SAMPLES_WATER) * viewRayLength * VL_WATER_DENSITY;
}
