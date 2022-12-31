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
    vec3 GetVolumetricLighting(const in LightData lightData, inout vec3 transmittance, const in vec3 viewNear, const in vec3 viewFar, const in vec2 scatteringF) {
        vec3 viewRayVector = viewFar - viewNear;
        float viewRayLength = length(viewRayVector);
        if (viewRayLength < EPSILON) return vec3(0.0);

        mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
        vec3 shadowViewStart = (matViewToShadowView * vec4(viewNear, 1.0)).xyz;
        vec3 shadowViewEnd = (matViewToShadowView * vec4(viewFar, 1.0)).xyz;

        vec3 shadowRayVector = shadowViewEnd - shadowViewStart;
        float shadowRayLength = length(shadowRayVector);
        const float stepF = rcp(VL_SAMPLES_SKY + 1.0);

        //vec3 rayDirection = shadowRayVector / shadowRayLength;
        float stepLength = shadowRayLength * stepF;
        vec3 rayStep = shadowRayVector * stepF;
        //vec3 accumColor = vec3(0.0);
        //float accumExt = 1.0;
        //float accumF = 0.0;
        //float accumD = 0.0;

        vec3 SmokeAbsorptionCoefficient = vec3(0.002);
        vec3 SmokeScatteringCoefficient = vec3(0.60);
        vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

        //vec3 fogColorLinear = RGBToLinear(fogColor);

        //float viewNearDist = length(viewNear);
        //float viewStepLength = viewRayLength * stepF;

        //float envFogStart = 0.0;
        //float envFogEnd = min(far, gl_Fog.end);
        //const float envFogDensity = 0.4;

        #ifdef VL_DITHER
            shadowViewStart += rayStep * GetScreenBayerValue();
        #endif

        #ifdef SHADOW_CLOUD
            vec3 viewLightDir = normalize(shadowLightPosition);
            vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;
            //vec3 localPosFar = (gbufferModelViewInverse * vec4(viewFar, 1.0)).xyz;

            //if (localLightDir.y <= 0.0) return vec3(0.0);

            //float cloudVis = 1.0 - GetCloudFactor(cameraPosition, localLightDir);
        #endif

        //mat4 gbufferModelViewProjection = gbufferProjection * gbufferModelView;
        float time = frameTimeCounter / 3600.0;
        vec3 shadowMax = 1.0 - vec3(vec2(shadowPixelSize), EPSILON);
        vec3 sampleAmbient = 48000.0 * RGBToLinear(fogColor);
        vec3 scattering = vec3(0.0);
        vec3 t;

        const float AirSpeed = 20.0;

        for (int i = 0; i < VL_SAMPLES_SKY; i++) {
            vec3 currentShadowViewPos = shadowViewStart + i * rayStep;
            vec3 localTracePos = (shadowModelViewInverse * vec4(currentShadowViewPos, 1.0)).xyz;

            //vec3 traceClipPos = unproject(gbufferModelViewProjection * vec4(localTracePos, 1.0)) * 2.0 - 1.0;
            //if (traceClipPos.z >= lightData.opaqueScreenDepth) continue;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                for (int i = 0; i < 4; i++) {
                    shadowPos[i] = (lightData.matShadowProjection[i] * vec4(currentShadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    shadowPos[i].xy = shadowPos[i].xy * 0.5 + lightData.shadowTilePos[i];
                }

                // TODO
                //if (saturate(shadowPos.xy) != shadowPos.xy) continue;

                int cascade = GetShadowSampleCascade(shadowPos, lightData.shadowProjectionSize, 0.0);

                float sampleF = CompareOpaqueDepth(shadowPos[cascade], vec2(0.0), lightData.shadowBias[cascade]);
            #else
                vec4 shadowPos = shadowProjection * vec4(currentShadowViewPos, 1.0);
                float sampleBias = 0.0;

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    float distortF = getDistortFactor(shadowPos.xy);
                    shadowPos.xyz = distort(shadowPos.xyz, distortF);

                    //sampleBias = GetShadowBias(0.0, distortF);
                #else
                    //sampleBias = ?;
                #endif

                shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

                if (shadowPos.xyz != clamp(shadowPos.xyz, vec3(0.0), shadowMax)) {
                    // TODO: perform a screenspace depth check?
                    // does not need to be sampled, ray is already screen-aligned and depth value will be constant

                    // vec3 viewPos = (gbufferModelView * vec4(localTracePos, 1.0)).xyz;
                    // vec3 clipPos = unproject(gbufferModelViewProjection * vec4(localTracePos, 1.0));
                    // if (clipPos.z >= lightData.opaqueScreenDepth) continue;
                    continue;
                }

                float sampleF = CompareOpaqueDepth(shadowPos, vec2(0.0), lightData.shadowBias);
            #endif

            vec3 worldTracePos = cameraPosition + localTracePos;

            #ifdef SHADOW_CLOUD
                sampleF *= 1.0 - GetCloudFactor(worldTracePos, localLightDir, 0);
            #endif

            //sampleF = 0.1 + 0.9 * sampleF;

            //float sampleDensity = 1.0 - saturate((worldTracePos.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));

            //#if VL_FOG_MIN != 0
                //if (worldTracePos.y < CLOUD_LEVEL) {
                    t = worldTracePos / 192.0;
                    t.xz -= time * 1.0 * AirSpeed;
                    float texDensity1 = texture(colortex13, t).r;

                    t = worldTracePos / 96.0;
                    t.xz += time * 2.0 * AirSpeed;
                    float texDensity2 = texture(colortex13, t).r;

                    t = worldTracePos / 48.0;
                    t.xyz += time * 4.0 * AirSpeed;
                    float texDensity3 = texture(colortex13, t).r;

                    //float texDensity = 1.0;//(0.2 + 0.8 * wetness) * (1.0 - mix(texDensity1, texDensity2, 0.1 + 0.5 * wetness));
                    float texDensity = 0.04 + pow(0.2 * texDensity1 * texDensity2, 2.0) + 0.7 * pow(texDensity3 * texDensity2, 4.0);//0.2 * (1.0 - mix(texDensity1, texDensity2, 0.5));
                    
                    // Change with altitude
                    float altD = 1.0 - saturate((worldTracePos.y - SEA_LEVEL) / (CLOUD_LEVEL - SEA_LEVEL));
                    texDensity *= pow3(altD);

                    // Change with weather
                    //texDensity *= VLFogMinF + (1.0 - VLFogMinF) * wetness;
                    texDensity *= 0.2 + 1.4 * wetness;

                    //sampleF *= texDensity;
                    //sampleAmbient *= texDensity;

                    //accumD += texDensity;

                    //vec3 stepExt = exp(-VL_SKY_DENSITY * viewStepLength * texDensity * AtmosExtInv);
                    //extinction *= stepExt;

                    //accumColor *= stepExt;
                //}
                //else {
                //    //sampleF *= 1.0 - smoothstep(CLOUD_LEVEL, ATMOSPHERE_LEVEL, worldTracePos.y);
                //    continue;
                //}
            //#endif

            //accumColor += sampleAmbient;

            //if (sampleF < EPSILON) continue;

            //float traceViewDist = viewNearDist + i * viewStepLength;
            //sampleF *= exp(-ATMOS_EXTINCTION * traceViewDist);

            //sampleF *= sampleDensity;

            vec3 sampleColor = 16.0 * GetScatteredLighting(worldTracePos.y, skyLightLevels, scatteringF) * sampleF;

            sampleColor += sampleAmbient;

            #ifdef SHADOW_COLOR
                //if (sampleF > EPSILON) {
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        float transparentShadowDepth = SampleTransparentDepth(shadowPos[cascade], vec2(0.0));
                    #else
                        float transparentShadowDepth = SampleTransparentDepth(shadowPos, vec2(0.0));
                    #endif

                    if (shadowPos.z - transparentShadowDepth >= EPSILON) {
                        vec3 shadowColor = GetShadowColor(shadowPos.xy);

                        if (!any(greaterThan(shadowColor, vec3(EPSILON)))) shadowColor = vec3(1.0);
                        shadowColor = normalize(shadowColor) * 1.73;

                        sampleColor *= shadowColor;
                    }
                //}
            #endif

            //sampleColor *= sampleF;

            // TODO: add ambient lighting?
            //sampleColor += sampleAmbient;

            // if (i > 0) {
            //     vec3 stepExt = exp(-(accumD / i) * (i * stepLength) * AtmosExtInv * VL_SKY_DENSITY * 2.0);
            //     sampleColor *= stepExt;
            // }

            //accumColor += sampleColor * sampleF;


            vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * stepLength * texDensity);
            vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

            scattering += sampleColor * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

            transmittance *= stepTransmittance;
        }

        //float traceLength = min(viewRayLength / min(far, gl_Fog.end), 1.0);

        //extinction = exp(-(accumD / VL_SAMPLES_SKY) * viewRayLength * AtmosExtInv * VL_SKY_DENSITY * 2.0);

        //return (accumColor / VL_SAMPLES_SKY) * viewRayLength * VL_SKY_DENSITY;
        return scattering;
    }
#endif

#ifdef VL_WATER_ENABLED
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

                int cascade = GetShadowSampleCascade(shadowPos, lightData.shadowProjectionSize, 0.0);

                lightSample = CompareOpaqueDepth(shadowPos[cascade], vec2(0.0), lightData.shadowBias[cascade]);

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
                    if (worldTracePos.y < CLOUD_LEVEL) {
                        lightSample *= 1.0 - GetCloudFactor(worldTracePos, localLightDir, 0);
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
                lightSample *= 1.0 - 0.6 * sampleDensity1 - 0.3 * sampleDensity2;
            #endif

            accumF += lightSample * lightColor * max(1.0 - waterF, 0.0);
        }

        //float traceLength = saturate(viewRayLength / far);
        return (accumF / VL_SAMPLES_WATER) * viewRayLength * VL_WATER_DENSITY;
    }
#endif
