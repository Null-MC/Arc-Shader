const float AirSpeed = 20.0;


#ifdef SKY_VL_ENABLED
    float GetSkyFogDensity(const in sampler3D tex, const in vec3 worldPos, const in float time) {
        vec3 texPos = worldPos.xzy;
        texPos.z *= 4.0;
        vec3 t;

        t = texPos / 192.0;
        t.xz -= time * 1.0 * AirSpeed;
        float texDensity1 = textureLod(tex, t, 0).r;

        t = texPos / 96.0;
        t.xz += time * 2.0 * AirSpeed;
        float texDensity2 = textureLod(tex, t, 0).r;

        t = texPos / 48.0;
        t.xyz += time * 4.0 * AirSpeed;
        float texDensity3 = textureLod(tex, t, 0).r;

        return 0.04 + 0.2 * pow(texDensity1 * texDensity2, 2.0) + 0.6 * pow(texDensity3 * texDensity2, 3.0);
    }

    void GetVolumetricLighting(out vec3 scattering, out vec3 transmittance, const in vec3 localViewDir, const in float nearDist, const in float farDist) {
        const float inverseStepCountF = rcp(SKY_VL_SAMPLES);
        
        #ifdef VL_DITHER
            float dither = Bayer16(gl_FragCoord.xy);
        #else
            const float dither = 0.0;
        #endif

        vec3 localStart = localViewDir * nearDist;
        vec3 localEnd = localViewDir * farDist;
        float localRayLength = farDist - nearDist;
        vec3 localStep = localViewDir * (localRayLength * inverseStepCountF);

        #ifndef IRIS_FEATURE_SSBO
            mat4 shadowModelViewEx = BuildShadowViewMatrix();
        #endif

        vec3 shadowViewStart = (shadowModelViewEx * vec4(localStart, 1.0)).xyz;
        vec3 shadowViewEnd = (shadowModelViewEx * vec4(localEnd, 1.0)).xyz;
        vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * inverseStepCountF;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowClipStart[4];
            vec3 shadowClipStep[4];
            for (int c = 0; c < 4; c++) {
                shadowClipStart[c] = (cascadeProjection[c] * vec4(shadowViewStart, 1.0)).xyz * 0.5 + 0.5;
                shadowClipStart[c].xy = shadowClipStart[c].xy * 0.5 + shadowProjectionPos[c];

                vec3 shadowClipEnd = (cascadeProjection[c] * vec4(shadowViewEnd, 1.0)).xyz * 0.5 + 0.5;
                shadowClipEnd.xy = shadowClipEnd.xy * 0.5 + shadowProjectionPos[c];

                shadowClipStep[c] = (shadowClipEnd - shadowClipStart[c]) * inverseStepCountF;
            }
        #else
            #ifndef IRIS_FEATURE_SSBO
                mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
            #endif

            vec3 shadowClipStart = (shadowProjectionEx * vec4(shadowViewStart, 1.0)).xyz;
            vec3 shadowClipEnd = (shadowProjectionEx * vec4(shadowViewEnd, 1.0)).xyz;
            vec3 shadowClipStep = (shadowClipEnd - shadowClipStart) * inverseStepCountF;
        #endif

        float localStepLength = localRayLength * inverseStepCountF;
        vec3 worldStart = localStart + cameraPosition;
        
        vec3 localLightDir = GetShadowLightLocalDir();
        vec3 localSunDir = GetSunLocalDir();

        #if SKY_CLOUD_LEVEL >= 0
            // TODO: this data probably already exists before this method
            float cloudVisibleDist = -1.0;
            float cloudVisibleF = 1.0;

            if (HasClouds(worldStart, localViewDir)) {
                vec3 cloudVisiblePos = GetCloudPosition(worldStart, localViewDir);
                cloudVisibleF = GetCloudFactor(cloudVisiblePos, localViewDir, 0);
                cloudVisibleDist = length(cloudVisiblePos - worldStart);

                //cloudVisibleF = 1.0 - smoothstep(0.0, 0.6, cloudVisibleF);
                cloudVisibleF = pow(1.0 - cloudVisibleF, 4.0);
            }
        #endif


        float time = frameTimeCounter / 3600.0;
        //vec3 shadowMax = 1.0 - vec3(vec2(shadowPixelSize), EPSILON);
        //float minFogF = min(VLFogMinF * (1.0 + 0.6 * max(skyLightLevels.x, 0.0)), 1.0);

        #ifndef SKY_VL_NOISE
            #ifdef WORLD_END
                const float texDensity = 9.6;
            #else
                const float texDensity = 1.0 + 0.7 * rainStrength;//mix(1.0, 2.8, rainStrength);
            #endif
        #endif

        float VoL = dot(localLightDir, localViewDir);
        float miePhaseValue = getMiePhase(VoL);
        float rayleighPhaseValue = getRayleighPhase(-VoL);

        const float atmosScale = (atmosphereRadiusMM - groundRadiusMM) / (ATMOSPHERE_LEVEL - SEA_LEVEL);

        scattering = vec3(0.0);
        transmittance = vec3(1.0);
        for (int i = 1; i < SKY_VL_SAMPLES; i++) {
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                const float sampleBias = 0.0;

                vec3 shadowViewPos = shadowViewStep * (i + dither) + shadowViewStart;
                vec3 traceShadowClipPos = vec3(0.0);

                int cascade = GetShadowCascade(shadowViewPos, -1.0);
                
                float sampleF = 0.0;
                if (cascade >= 0) {
                    traceShadowClipPos = shadowClipStart[cascade] + (i + dither) * shadowClipStep[cascade];
                    sampleF = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), sampleBias);
                }
            #else
                const float sampleBias = 0.0;

                vec3 traceShadowClipPos = shadowClipStep * (i + dither) + shadowClipStart;

                traceShadowClipPos = distort(traceShadowClipPos);

                traceShadowClipPos = traceShadowClipPos * 0.5 + 0.5;

                float sampleF = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), sampleBias);
            #endif

            vec3 traceWorldPos = localStep * (i + dither) + worldStart;

            #if defined WORLD_CLOUDS_ENABLED && SKY_CLOUD_LEVEL >= 0
                float traceDist = localStepLength * (i + dither);
                if (cloudVisibleDist > 0.0 && traceDist > cloudVisibleDist) {
                    //transmittance *= cloudVisibleF;
                    cloudVisibleDist = -1.0;
                }

                #ifdef SHADOW_CLOUD
                    if (HasClouds(traceWorldPos, localLightDir)) {
                        vec3 cloudShadowPos = GetCloudPosition(traceWorldPos, localLightDir);
                        float cloudShadowF = GetCloudFactor(cloudShadowPos, traceWorldPos, localLightDir, 0);
                        cloudShadowF = 1.0 - smoothstep(0.0, 0.3, cloudShadowF);
                        //sampleF *= 1.0 - min(cloudShadowF * 6.0, 1.0);
                        sampleF *= cloudShadowF;

                        //cloudF = min((1.0 - cloudF) * 2.0, 1.0);
                        //sampleF *= pow(1.0 - cloudF, 4.0);

                        //transmittance *= 1.0 - cloudF;
                    }
                #endif
            #endif

            #ifdef SKY_VL_NOISE
                float texDensity = GetSkyFogDensity(TEX_CLOUD_NOISE, traceWorldPos, time);

                #ifdef WORLD_END
                    texDensity = 1.0 + 60.0 * texDensity;
                #else
                    // Change with altitude
                    float altD = 1.0 - saturate((traceWorldPos.y - SEA_LEVEL) / (SKY_CLOUD_LEVEL - SEA_LEVEL));
                    altD = smoothstep(0.1, 1.0, altD);

                    // Change with weather
                    //texDensity *= minFogF + (1.0 - minFogF) * wetness;

                    //texDensity = 1.0 + (32.0 + rainStrength * 32.0) * texDensity;
                    texDensity = 1.0 + 256.0 * altD * pow(texDensity, 2.0);
                #endif
            #endif

            vec3 sampleColor = vec3(1.0);

            #ifdef SHADOW_COLOR
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    float transparentShadowDepth = SampleTransparentDepth(traceShadowClipPos.xy, vec2(0.0));
                #else
                    float transparentShadowDepth = SampleTransparentDepth(traceShadowClipPos.xy, vec2(0.0));
                #endif

                if (traceShadowClipPos.z - transparentShadowDepth >= EPSILON) {
                    vec3 shadowColor = GetShadowColor(traceShadowClipPos.xy);

                    if (!any(greaterThan(shadowColor, vec3(EPSILON)))) shadowColor = vec3(1.0);
                    shadowColor = normalize(shadowColor) * 1.73;

                    sampleColor *= shadowColor;
                }
            #endif

            vec3 atmosPos = GetAtmospherePosition(traceWorldPos);
            float sampleElevation = length(atmosPos) - groundRadiusMM;

            float mieScattering;
            vec3 rayleighScattering, extinction;
            getScatteringValues(atmosPos, texDensity, rayleighScattering, mieScattering, extinction);

            float dt = localStepLength * atmosScale;// * texDensity;
            vec3 sampleTransmittance = exp(-dt*extinction);

            #ifdef IS_IRIS
                vec3 sunTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.x);
            #else
                vec3 sunTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.x);
            #endif

            vec3 lightTransmittance = sunTransmittance * skySunColor * SunLux;

            #ifdef WORLD_MOON_ENABLED
                #ifdef IS_IRIS
                    vec3 moonTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.y);
                #else
                    vec3 moonTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.y);
                #endif

                lightTransmittance += moonTransmittance * skyMoonColor * MoonLux * GetMoonPhaseLevel();
            #endif

            lightTransmittance *= sampleColor * sampleF;

            #ifdef IS_IRIS
                vec3 psiMS = getValFromMultiScattLUT(texMultipleScattering, atmosPos, localSunDir);
            #else
                vec3 psiMS = getValFromMultiScattLUT(colortex13, atmosPos, localSunDir);
            #endif

            psiMS *= (sampleF*0.6 + 0.4) * SKY_FANCY_LUM * (eyeBrightnessSmooth.y / 240.0);

            vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * lightTransmittance + psiMS);
            vec3 mieInScattering = mieScattering * (miePhaseValue * lightTransmittance + psiMS);
            vec3 inScattering = (rayleighInScattering + mieInScattering);

            // Integrated scattering within path segment.
            vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

            scattering += scatteringIntegral * transmittance;
            transmittance *= sampleTransmittance;
        }
    }
#endif

#ifdef WATER_VL_ENABLED
    vec3 GetScatteredLighting(const in vec2 scatteringF, const in float elevation) {
        #ifdef IS_IRIS
            vec3 sunTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.x);
        #else
            vec3 sunTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.x);
        #endif

        vec3 result = scatteringF.x * sunTransmittance * skySunColor * SunLux * max(skyLightLevels.x, 0.0);

        #ifdef WORLD_MOON_ENABLED
            #ifdef IS_IRIS
                vec3 moonTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.y);
            #else
                vec3 moonTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.y);
            #endif

            result += scatteringF.y * moonTransmittance * skyMoonColor * MoonLux * max(skyLightLevels.y, 0.0) * GetMoonPhaseLevel();
        #endif

        return result;
    }

    float GetWaterFogDensity(const in sampler3D tex, const in vec3 worldPos) {
        vec3 texPos = worldPos.xzy;
        texPos.z *= 4.0;

        float sampleDensity1 = textureLod(tex, texPos / 96.0, 0).r;
        float sampleDensity2 = textureLod(tex, texPos / 16.0, 0).r;
        return 0.65 * sampleDensity1 - 0.35 * sampleDensity2;
    }

    void GetWaterVolumetricLighting(out vec3 scattering, out vec3 transmittance, const in vec2 scatteringF, const in vec3 localViewDir, const in float nearDist, const in float farDist) {
        const float inverseStepCountF = rcp(WATER_VL_SAMPLES - 1);

        #ifdef SHADOW_CLOUD
            vec3 localLightDir = GetShadowLightLocalDir();
            // if (localLightDir.y <= 0.0) {
            //     return vec4(0.0, 0.0, 0.0, 1.0);
            // }
        #endif

        #ifdef VL_DITHER
            float dither = Bayer16(gl_FragCoord.xy);
        #else
            const float dither = 0.0;
        #endif

        vec3 localStart = localViewDir * nearDist;
        vec3 localEnd = localViewDir * farDist;
        float localRayLength = farDist - nearDist;
        vec3 localStep = localViewDir * (localRayLength * inverseStepCountF);

        #ifndef IRIS_FEATURE_SSBO
            mat4 shadowModelViewEx = BuildShadowViewMatrix();
        #endif

        vec3 shadowViewStart = (shadowModelViewEx * vec4(localStart, 1.0)).xyz;
        vec3 shadowViewEnd = (shadowModelViewEx * vec4(localEnd, 1.0)).xyz;
        vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * inverseStepCountF;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 shadowClipStart[4];
            vec3 shadowClipStep[4];
            for (int c = 0; c < 4; c++) {
                shadowClipStart[c] = (cascadeProjection[c] * vec4(shadowViewStart, 1.0)).xyz * 0.5 + 0.5;
                shadowClipStart[c].xy = shadowClipStart[c].xy * 0.5 + shadowProjectionPos[c];

                vec3 shadowClipEnd = (cascadeProjection[c] * vec4(shadowViewEnd, 1.0)).xyz * 0.5 + 0.5;
                shadowClipEnd.xy = shadowClipEnd.xy * 0.5 + shadowProjectionPos[c];

                shadowClipStep[c] = (shadowClipEnd - shadowClipStart[c]) * inverseStepCountF;
            }
        #else
            #ifndef IRIS_FEATURE_SSBO
                mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
            #endif
        
            vec3 shadowClipStart = (shadowProjectionEx * vec4(shadowViewStart, 1.0)).xyz;
            vec3 shadowClipEnd = (shadowProjectionEx * vec4(shadowViewEnd, 1.0)).xyz;
            vec3 shadowClipStep = (shadowClipEnd - shadowClipStart) * inverseStepCountF;
        #endif

        float localStepLength = localRayLength * inverseStepCountF;
        vec3 worldStart = localStart + cameraPosition;

        vec3 accumF = vec3(0.0);
        float lightSample, transparentDepth;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            float MaxShadowDist = far * 3.0;
        #else
            float MaxShadowDist = far * 2.0;
        #endif

        vec3 absorptionCoefficientBase = 1.0 - waterAbsorbColor;
        vec3 scatteringCoefficientBase = waterScatterColor;

        float skyLight = saturate(eyeBrightnessSmooth.y / 240.0);
        vec3 skyAmbientBase = (0.25 / PI) * GetFancySkyAmbientLight(vec3(0.0, 1.0, 0.0));

        #ifndef WATER_VL_NOISE
            const float texDensity = 1.0;
        #endif

        scattering = vec3(0.0);
        transmittance = vec3(1.0);
        for (int i = 1; i < WATER_VL_SAMPLES; i++) {
            transparentDepth = 1.0;
            float traceLightDist = far;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                const float bias = 0.0; // TODO

                vec3 shadowViewPos = shadowViewStep * (i + dither) + shadowViewStart;
                vec3 traceShadowClipPos = vec3(0.0);

                int cascade = GetShadowCascade(shadowViewPos, -0.05);

                lightSample = 0.0;
                if (cascade >= 0) {
                    traceShadowClipPos = shadowClipStart[cascade] + (i + dither) * shadowClipStep[cascade];
                    //lightSample = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), bias);
                    float opaqueDepth = SampleOpaqueDepth(traceShadowClipPos.xy, vec2(0.0));
                    lightSample = step(traceShadowClipPos.z - bias, opaqueDepth);

                    if (lightSample > EPSILON) {
                        transparentDepth = SampleTransparentDepth(traceShadowClipPos.xy, vec2(0.0));

                        traceLightDist = max(traceShadowClipPos.z - transparentDepth, 0.0) * (far * 3.0);
                    }
                }
            #else
                const float bias = 0.0; // TODO
            
                vec3 traceShadowClipPos = shadowClipStart + shadowClipStep * (i + dither);

                traceShadowClipPos = distort(traceShadowClipPos) * 0.5 + 0.5;

                //lightSample = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), bias);
                float opaqueDepth = SampleOpaqueDepth(traceShadowClipPos.xy, vec2(0.0));
                lightSample = step(traceShadowClipPos.z - bias, opaqueDepth);

                if (lightSample > EPSILON) {
                    transparentDepth = SampleTransparentDepth(traceShadowClipPos.xy, vec2(0.0));

                    traceLightDist = max(traceShadowClipPos.z - transparentDepth, 0.0) * (far * 2.0);
                }
            #endif

            vec3 traceWorldPos = worldStart + localStep * (i + dither);

            #if defined WORLD_CLOUDS_ENABLED && defined SHADOW_CLOUD
                if (HasClouds(traceWorldPos, localLightDir)) {
                    vec3 cloudPos = GetCloudPosition(traceWorldPos, localLightDir);
                    float cloudF = GetCloudFactor(cloudPos, localLightDir, 0);
                    lightSample *= pow(1.0 - cloudF, 4.0);
                }
            #endif

            #ifdef WATER_VL_NOISE
                float texDensity = 0.8 + 1.2 * GetWaterFogDensity(TEX_CLOUD_NOISE, traceWorldPos);
            #endif

            vec3 absorptionCoefficient = texDensity * absorptionCoefficientBase;
            vec3 scatteringCoefficient = texDensity * scatteringCoefficientBase;
            vec3 extinctionCoefficient = scatteringCoefficient + absorptionCoefficient;

            vec3 scatteringAlbedo = scatteringCoefficient / extinctionCoefficient;
            vec3 multipleScatteringFactor = scatteringAlbedo;// * 0.87;

            vec3 multipleScatteringIntegral = multipleScatteringFactor / (1.0 - multipleScatteringFactor);

            vec3 atmosPos = GetAtmospherePosition(traceWorldPos);
            float sampleElevation = length(atmosPos) - groundRadiusMM;

            vec3 lightColor = exp(-extinctionCoefficient * traceLightDist);

            vec3 stepTransmittance = exp(-extinctionCoefficient * localStepLength);
            vec3 scatteringIntegral = (1.0 - stepTransmittance) / extinctionCoefficient;

            vec3 directLightColor = lightSample * lightColor * GetScatteredLighting(scatteringF, sampleElevation);
            vec3 singleScattering = directLightColor * (scatteringCoefficient * scatteringIntegral);

            vec3 indirectLightColor = GetScatteredLighting(vec2(0.25 / PI), sampleElevation);
            indirectLightColor *= exp(-extinctionCoefficient * traceLightDist);
            indirectLightColor += skyAmbientBase * exp(-extinctionCoefficient * mix(80.0, 0.0, skyLight));
            vec3 multiScattering = 0.03 * indirectLightColor * (multipleScatteringIntegral * scatteringIntegral);

            scattering += (singleScattering + multiScattering) * transmittance;

            transmittance *= stepTransmittance;
        }
    }
#endif
