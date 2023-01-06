vec3 GetScatteredLighting(const in float worldTraceHeight, const in vec2 skyLightLevels, const in vec2 scatteringF) {
    #ifdef RENDER_DEFERRED
        vec3 sunTransmittance = GetSunTransmittance(colortex7, worldTraceHeight, skyLightLevels.x);
        vec3 moonTransmittance = GetMoonTransmittance(colortex7, worldTraceHeight, skyLightLevels.y);
    #else
        vec3 sunTransmittance = GetSunTransmittance(colortex9, worldTraceHeight, skyLightLevels.x);
        vec3 moonTransmittance = GetMoonTransmittance(colortex9, worldTraceHeight, skyLightLevels.y);
    #endif

    return
        scatteringF.x * sunTransmittance * sunColor * max(skyLightLevels.x, 0.0) +
        scatteringF.y * moonTransmittance * GetMoonPhaseLevel() * moonColor * max(skyLightLevels.y, 0.0);
}

const float isotropicPhase = 0.25 / PI;

#ifdef VL_SKY_ENABLED
    vec3 GetVolumetricLighting(const in LightData lightData, inout vec3 transmittance, const in vec3 nearViewPos, const in vec3 farViewPos, const in vec2 scatteringF) {
        const float inverseStepCountF = rcp(VL_SAMPLES_SKY + 1);
        
        #ifdef VL_DITHER
            float dither = GetScreenBayerValue();
        #else
            const float dither = 0.0;
        #endif

        vec3 localStart = (gbufferModelViewInverse * vec4(nearViewPos, 1.0)).xyz;
        vec3 localEnd = (gbufferModelViewInverse * vec4(farViewPos, 1.0)).xyz;
        vec3 localRay = localEnd - localStart;
        float localRayLength = length(localRay);
        vec3 localStep = localRay * inverseStepCountF;

        vec3 shadowViewStart = (shadowModelView * vec4(localStart, 1.0)).xyz;
        vec3 shadowViewEnd = (shadowModelView * vec4(localEnd, 1.0)).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowClipStart[4];
            vec3 shadowClipStep[4];
            for (int c = 0; c < 4; c++) {
                shadowClipStart[c] = (lightData.matShadowProjection[c] * vec4(shadowViewStart, 1.0)).xyz * 0.5 + 0.5;
                shadowClipStart[c].xy = shadowClipStart[c].xy * 0.5 + lightData.shadowTilePos[c];

                vec3 shadowClipEnd = (lightData.matShadowProjection[c] * vec4(shadowViewEnd, 1.0)).xyz * 0.5 + 0.5;
                shadowClipEnd.xy = shadowClipEnd.xy * 0.5 + lightData.shadowTilePos[c];

                shadowClipStep[c] = (shadowClipEnd - shadowClipStart[c]) * inverseStepCountF;
            }
        #else
            vec3 shadowClipStart = (shadowProjection * vec4(shadowViewStart, 1.0)).xyz;
            vec3 shadowClipEnd = (shadowProjection * vec4(shadowViewEnd, 1.0)).xyz;
            vec3 shadowClipStep = (shadowClipEnd - shadowClipStart) * inverseStepCountF;
        #endif

        float localStepLength = localRayLength * inverseStepCountF;
        vec3 worldStart = localStart + cameraPosition;
        
        vec3 SmokeAbsorptionCoefficient = vec3(0.002);
        vec3 SmokeScatteringCoefficient = vec3(0.46);
        vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

        #ifdef SHADOW_CLOUD
            vec3 viewLightDir = normalize(shadowLightPosition);
            vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;
        #endif

        #if ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
            float cameraSkyLight = saturate(eyeBrightnessSmooth.y / 240.0);
            vec3 sampleAmbient = vec3(mix(NightSkyLumen, 32000.0 * pow2(cameraSkyLight), max(lightData.skyLightLevels.x, 0.0)));
        #else
            float cameraSkyLight = saturate(eyeBrightnessSmooth.y / 240.0);
            vec3 sampleAmbient = NightSkyLumen + 32000.0 * RGBToLinear(fogColor) * pow2(cameraSkyLight);
        #endif

        const float AirSpeed = 20.0;
        float time = frameTimeCounter / 3600.0;
        vec3 shadowMax = 1.0 - vec3(vec2(shadowPixelSize), EPSILON);
        vec3 t;

        vec3 scattering = vec3(0.0);
        for (int i = 0; i < VL_SAMPLES_SKY; i++) {
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                for (int c = 0; c < 4; c++)
                    shadowPos[c] = shadowClipStart[c] + (i + dither) * shadowClipStep[c];

                int cascade = GetShadowSampleCascade(shadowPos, lightData.shadowProjectionSize, 0.0);

                float sampleF = CompareOpaqueDepth(shadowPos[cascade], vec2(0.0), lightData.shadowBias[cascade]);
            #else
                vec3 traceShadowClipPos = shadowClipStart + shadowClipStep * (i + dither);

                float sampleBias = 0.0;

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    traceShadowClipPos = distort(traceShadowClipPos);

                    //sampleBias = GetShadowBias(0.0, distortF);
                #else
                    //sampleBias = ?;
                #endif

                traceShadowClipPos = traceShadowClipPos * 0.5 + 0.5;

                if (traceShadowClipPos != clamp(traceShadowClipPos, vec3(0.0), shadowMax)) {
                    // TODO: perform a screenspace depth check?
                    continue;
                }

                float sampleF = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), lightData.shadowBias);
            #endif

            sampleF = 0.2 + 0.8 * sampleF;

            vec3 traceWorldPos = worldStart + localStep * (i + dither);

            #ifdef SHADOW_CLOUD
                sampleF *= 1.0 - GetCloudFactor(traceWorldPos, localLightDir, 0);
            #endif

            t = traceWorldPos / 192.0;
            t.xz -= time * 1.0 * AirSpeed;
            float texDensity1 = texture(colortex13, t).r;

            t = traceWorldPos / 96.0;
            t.xz += time * 2.0 * AirSpeed;
            float texDensity2 = texture(colortex13, t).r;

            t = traceWorldPos / 48.0;
            t.xyz += time * 4.0 * AirSpeed;
            float texDensity3 = texture(colortex13, t).r;

            //float texDensity = 1.0;//(0.2 + 0.8 * wetness) * (1.0 - mix(texDensity1, texDensity2, 0.1 + 0.5 * wetness));
            float texDensity = 0.04 + 0.2 * pow(texDensity1 * texDensity2, 2.0) + 0.6 * pow(texDensity3 * texDensity2, 3.0);//0.2 * (1.0 - mix(texDensity1, texDensity2, 0.5));
            
            // Change with altitude
            float altD = 1.0 - saturate((traceWorldPos.y - SEA_LEVEL) / (CLOUD_LEVEL - SEA_LEVEL));
            texDensity *= pow3(altD);

            // Change with weather
            //texDensity *= VLFogMinF + (1.0 - VLFogMinF) * wetness;
            //texDensity *= 0.2 + 1.4 * wetness;
            float minFogF = min(VLFogMinF * (1.0 + 0.6 * max(lightData.skyLightLevels.x, 0.0)), 1.0);
            texDensity *= minFogF + (1.0 - minFogF) * wetness;

            vec3 sampleColor = 16.0 * GetScatteredLighting(traceWorldPos.y, skyLightLevels, scatteringF) * sampleF;

            sampleColor += sampleAmbient;

            #ifdef SHADOW_COLOR
                //if (sampleF > EPSILON) {
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        float transparentShadowDepth = SampleTransparentDepth(shadowPos[cascade].xy, vec2(0.0));
                    #else
                        float transparentShadowDepth = SampleTransparentDepth(traceShadowClipPos.xy, vec2(0.0));
                    #endif

                    if (traceShadowClipPos.z - transparentShadowDepth >= EPSILON) {
                        vec3 shadowColor = GetShadowColor(traceShadowClipPos.xy);

                        if (!any(greaterThan(shadowColor, vec3(EPSILON)))) shadowColor = vec3(1.0);
                        shadowColor = normalize(shadowColor) * 1.73;

                        sampleColor *= shadowColor;
                    }
                //}
            #endif

            vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * localStepLength * texDensity);
            vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

            scattering += sampleColor * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

            transmittance *= stepTransmittance;
        }

        return scattering;
    }
#endif

#ifdef VL_WATER_ENABLED
    vec3 GetWaterVolumetricLighting(const in LightData lightData, const in vec3 nearViewPos, const in vec3 farViewPos, const in vec2 scatteringF) {
        const float inverseStepCountF = rcp(VL_SAMPLES_WATER + 1);

        #ifdef SHADOW_CLOUD
            vec3 viewLightDir = normalize(shadowLightPosition);
            vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;

            //vec3 upDir = normalize(upPosition);
            //float horizonFogF = 1.0 - abs(dot(viewLightDir, upDir));

            if (localLightDir.y <= 0.0) return vec3(0.0);
        #endif

        #ifdef VL_DITHER
            float dither = GetScreenBayerValue();
        #else
            const float dither = 0.0;
        #endif

        vec3 localStart = (gbufferModelViewInverse * vec4(nearViewPos, 1.0)).xyz;
        vec3 localEnd = (gbufferModelViewInverse * vec4(farViewPos, 1.0)).xyz;
        vec3 localRay = localEnd - localStart;
        float localRayLength = length(localRay);
        vec3 localStep = localRay * inverseStepCountF;

        vec3 shadowViewStart = (shadowModelView * vec4(localStart, 1.0)).xyz;
        vec3 shadowViewEnd = (shadowModelView * vec4(localEnd, 1.0)).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowClipStart[4];
            vec3 shadowClipStep[4];
            for (int c = 0; c < 4; c++) {
                shadowClipStart[c] = (lightData.matShadowProjection[c] * vec4(shadowViewStart, 1.0)).xyz * 0.5 + 0.5;
                shadowClipStart[c].xy = shadowClipStart[c].xy * 0.5 + lightData.shadowTilePos[c];

                vec3 shadowClipEnd = (lightData.matShadowProjection[c] * vec4(shadowViewEnd, 1.0)).xyz * 0.5 + 0.5;
                shadowClipEnd.xy = shadowClipEnd.xy * 0.5 + lightData.shadowTilePos[c];

                shadowClipStep[c] = (shadowClipEnd - shadowClipStart[c]) * inverseStepCountF;
            }
        #else
            vec3 shadowClipStart = (shadowProjection * vec4(shadowViewStart, 1.0)).xyz;
            vec3 shadowClipEnd = (shadowProjection * vec4(shadowViewEnd, 1.0)).xyz;
            vec3 shadowClipStep = (shadowClipEnd - shadowClipStart) * inverseStepCountF;
        #endif

        float localStepLength = localRayLength * inverseStepCountF;
        vec3 worldStart = localStart + cameraPosition;

        vec3 accumF = vec3(0.0);
        float lightSample, transparentDepth;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            float MaxShadowDist = far * 3.0;
        #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            const float MaxShadowDist = 512.0;
        #else
            const float MaxShadowDist = 256.0;
        #endif

        vec3 extinctionInv = (1.0 - waterAbsorbColor) * WATER_ABSROPTION_RATE;

        for (int i = 1; i <= VL_SAMPLES_WATER; i++) {
            transparentDepth = 1.0;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                for (int c = 0; c < 4; c++)
                    shadowPos[c] = shadowClipStart[c] + (i + dither) * shadowClipStep[c];

                int cascade = GetShadowSampleCascade(shadowPos, lightData.shadowProjectionSize, 0.0);

                lightSample = CompareOpaqueDepth(shadowPos[cascade], vec2(0.0), lightData.shadowBias[cascade]);

                int waterOpaqueCascade = -1;
                if (lightSample > EPSILON)
                    transparentDepth = GetNearestTransparentDepth(shadowPos, lightData.shadowTilePos, vec2(0.0), waterOpaqueCascade);

                vec3 traceShadowClipPos = waterOpaqueCascade >= 0
                    ? shadowPos[waterOpaqueCascade]
                    : shadowPos[cascade];
            #else
                vec3 traceShadowClipPos = shadowClipStart + shadowClipStep * (i + dither);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    traceShadowClipPos = distort(traceShadowClipPos);
                #endif

                traceShadowClipPos = traceShadowClipPos * 0.5 + 0.5;

                // if (saturate(shadowPos.xy) != shadowPos.xy) {
                //     vec3 lightColor2 = GetScatteredLighting(worldTraceHeight, skyLightLevels, scatteringF);
                //     accumF += lightColor2 * 10000.0;// * exp(-(i * viewStepLength) * extinctionInv);
                //     return vec3(10000.0, 0.0, 0.0);
                // }

                lightSample = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), 0.0);

                if (lightSample > EPSILON)
                    transparentDepth = SampleTransparentDepth(traceShadowClipPos.xy, vec2(0.0));
            #endif

            vec3 traceWorldPos = worldStart + localStep * (i + dither);

            #ifdef SHADOW_CLOUD
                // when light is shining upwards
                // if (localLightDir.y <= 0.0) {
                //     lightSample = 0.0;
                // }
                // when light is shining downwards
                //else {
                    // when trace pos is below clouds, darken by cloud shadow
                    if (traceWorldPos.y < CLOUD_LEVEL) {
                        lightSample *= 1.0 - GetCloudFactor(traceWorldPos, localLightDir, 0);
                    }
                //}
            #endif

            float waterLightDist = max((traceShadowClipPos.z - transparentDepth) * MaxShadowDist, 0.0);
            waterLightDist += i * localStepLength;

            vec3 lightColor = GetScatteredLighting(traceWorldPos.y, lightData.skyLightLevels, scatteringF);
            lightColor *= exp(-waterLightDist * extinctionInv);

            // sample normal, get fresnel, darken
            uint data = textureLod(shadowcolor1, traceShadowClipPos.xy, 0).g;
            vec3 normal = unpackUnorm4x8(data).xyz;
            normal = normalize(normal * 2.0 - 1.0);
            float NoL = max(normal.z, 0.0);
            float waterF = F_schlick(NoL, 0.02, 1.0);

            #ifdef VL_WATER_NOISE
                float sampleDensity1 = texture(colortex13, traceWorldPos / 96.0).r;
                float sampleDensity2 = texture(colortex13, traceWorldPos / 16.0).r;
                lightSample *= 1.0 - 0.6 * sampleDensity1 - 0.3 * sampleDensity2;
            #endif

            accumF += lightSample * lightColor * max(1.0 - waterF, 0.0);
        }

        return (accumF / VL_SAMPLES_WATER) * localRayLength * VL_WATER_DENSITY;
    }
#endif
