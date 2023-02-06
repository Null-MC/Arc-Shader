const float AirSpeed = 20.0;
const float isotropicPhase = 0.25 / PI;


#ifdef VL_SKY_ENABLED
    float GetSkyFogDensity(const in sampler3D tex, const in vec3 worldPos, const in float time) {
        vec3 t;

        t = worldPos / 192.0;
        t.xz -= time * 1.0 * AirSpeed;
        float texDensity1 = textureLod(tex, t, 0).r;

        t = worldPos / 96.0;
        t.xz += time * 2.0 * AirSpeed;
        float texDensity2 = textureLod(tex, t, 0).r;

        t = worldPos / 48.0;
        t.xyz += time * 4.0 * AirSpeed;
        float texDensity3 = textureLod(tex, t, 0).r;

        return 0.04 + 0.2 * pow(texDensity1 * texDensity2, 2.0) + 0.6 * pow(texDensity3 * texDensity2, 3.0);
    }

    void GetVolumetricLighting(out vec3 scattering, out vec3 transmittance, const in vec3 localViewDir, const in float nearDist, const in float farDist) {
        const float inverseStepCountF = rcp(VL_SAMPLES_SKY + 1);
        
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
        
        //#ifdef SHADOW_CLOUD
            vec3 localLightDir = GetShadowLightLocalDir();
            //vec3 viewLightDir = mat3(gbufferModelView) * localLightDir;
            vec3 localSunDir = GetSunLocalDir();
        //#endif

        float time = frameTimeCounter / 3600.0;
        //vec3 shadowMax = 1.0 - vec3(vec2(shadowPixelSize), EPSILON);
        //float minFogF = min(VLFogMinF * (1.0 + 0.6 * max(skyLightLevels.x, 0.0)), 1.0);

        #ifndef VL_FOG_NOISE
            #ifdef WORLD_END
                const float texDensity = 9.6;
            #else
                const float texDensity = FogDensityF;//mix(1.0, 2.8, rainStrength);
            #endif
        #endif

        float VoL = dot(localLightDir, localViewDir);
        float miePhaseValue = getMiePhase(VoL);
        float rayleighPhaseValue = getRayleighPhase(-VoL);

        const float atmosScale = (atmosphereRadiusMM - groundRadiusMM) / (ATMOSPHERE_LEVEL - SEA_LEVEL);

        scattering = vec3(0.0);
        transmittance = vec3(1.0);
        for (int i = VL_SAMPLES_SKY-1; i > 0; i--) {
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                const float sampleBias = 0.0;

                vec3 shadowViewPos = shadowViewStart + (i + dither) * shadowViewStep;
                vec3 traceShadowClipPos = vec3(0.0);

                int cascade = GetShadowCascade(shadowViewPos, -1.0);
                
                float sampleF = 0.0;
                if (cascade >= 0) {
                    traceShadowClipPos = shadowClipStart[cascade] + (i + dither) * shadowClipStep[cascade];
                    sampleF = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), sampleBias);
                }
            #else
                const float sampleBias = 0.0;

                vec3 traceShadowClipPos = shadowClipStart + shadowClipStep * (i + dither);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    traceShadowClipPos = distort(traceShadowClipPos);

                    //sampleBias = GetShadowBias(0.0, distortF);
                #else
                    //sampleBias = ?;
                #endif

                traceShadowClipPos = traceShadowClipPos * 0.5 + 0.5;

                float sampleF = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), sampleBias);
            #endif

            vec3 traceWorldPos = worldStart + localStep * (i + dither);

            #if defined WORLD_CLOUDS_ENABLED && defined SHADOW_CLOUD
                if (HasClouds(traceWorldPos, localLightDir)) {
                    vec3 cloudPos = GetCloudPosition(traceWorldPos, localLightDir);
                    float cloudF = GetCloudFactor(cloudPos, localLightDir, 0);
                    sampleF *= pow(1.0 - cloudF, 4.0);
                }
            #endif

            #ifdef VL_FOG_NOISE
                #if SHADER_PLATFORM == PLATFORM_IRIS
                    float texDensity = GetSkyFogDensity(texCloudNoise, traceWorldPos, time);
                #else
                    float texDensity = GetSkyFogDensity(colortex14, traceWorldPos, time);
                #endif

                #ifdef WORLD_END
                    texDensity = 1.0 + 60.0 * texDensity;
                #else
                    // Change with altitude
                    float altD = 1.0 - saturate((traceWorldPos.y - SEA_LEVEL) / (CLOUD_LEVEL - SEA_LEVEL));
                    texDensity *= smoothstep(0.1, 1.0, altD);

                    // Change with weather
                    //texDensity *= minFogF + (1.0 - minFogF) * wetness;

                    texDensity = 1.0 + (8.0 + rainStrength * 32.0) * texDensity;
                #endif
            #endif

            vec3 sampleColor = vec3(1.0);

            #ifdef SHADOW_COLOR
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
            #endif

            vec3 atmosPos = GetAtmospherePosition(traceWorldPos);
            float sampleElevation = length(atmosPos) - groundRadiusMM;

            float mieScattering;
            vec3 rayleighScattering, extinction;
            getScatteringValues(atmosPos, rayleighScattering, mieScattering, extinction);

            float dt = localStepLength * atmosScale * texDensity;
            vec3 sampleTransmittance = exp(-dt*extinction);

            #if SHADER_PLATFORM == PLATFORM_IRIS
                vec3 sunTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.x);
            #else
                vec3 sunTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.x);
            #endif

            vec3 lightTransmittance = sunTransmittance * skySunColor * SunLux;

            #ifdef WORLD_MOON_ENABLED
                #if SHADER_PLATFORM == PLATFORM_IRIS
                    vec3 moonTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.y);
                #else
                    vec3 moonTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.y);
                #endif

                lightTransmittance += moonTransmittance * skyMoonColor * MoonLux;
            #endif

            lightTransmittance *= sampleColor * sampleF;

            #if SHADER_PLATFORM == PLATFORM_IRIS
                vec3 psiMS = getValFromMultiScattLUT(texMultipleScattering, atmosPos, localSunDir) * SKY_FANCY_LUM;
            #else
                vec3 psiMS = getValFromMultiScattLUT(colortex13, atmosPos, localSunDir) * SKY_FANCY_LUM;
            #endif

            //psiMS *= 0.4;
            psiMS *= (eyeBrightnessSmooth.y / 240.0);

            vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * lightTransmittance + psiMS);
            vec3 mieInScattering = mieScattering * (miePhaseValue * lightTransmittance + psiMS);
            vec3 inScattering = (rayleighInScattering + mieInScattering);

            // Integrated scattering within path segment.
            vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

            scattering += scatteringIntegral * transmittance;
            transmittance *= sampleTransmittance;
        }

        //return vec4(scattering, transmittance);
    }
#endif

#ifdef VL_WATER_ENABLED
    // vec3 GetScatteredLighting(const in float elevation, const in vec2 scatteringF) {
    //     #if SHADER_PLATFORM == PLATFORM_IRIS
    //         vec3 sunTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.x);
    //     #else
    //         vec3 sunTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.x);
    //     #endif

    //     vec3 result = scatteringF.x * sunTransmittance * skySunColor * SunLux * max(skyLightLevels.x, 0.0);

    //     #ifdef WORLD_MOON_ENABLED
    //         #if SHADER_PLATFORM == PLATFORM_IRIS
    //             vec3 moonTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.y);
    //         #else
    //             vec3 moonTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.y);
    //         #endif

    //         result += scatteringF.y * moonTransmittance * GetMoonPhaseLevel() * skyMoonColor * MoonLux * max(skyLightLevels.y, 0.0);
    //     #endif

    //     return result;
    // }

    vec3 GetScatteredLighting(const in float elevation) {
        #if SHADER_PLATFORM == PLATFORM_IRIS
            vec3 sunTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.x);
        #else
            vec3 sunTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.x);
        #endif

        vec3 result = sunTransmittance * skySunColor * SunLux * max(skyLightLevels.x, 0.0);

        #ifdef WORLD_MOON_ENABLED
            #if SHADER_PLATFORM == PLATFORM_IRIS
                vec3 moonTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.y);
            #else
                vec3 moonTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.y);
            #endif

            result += moonTransmittance * skyMoonColor * MoonLux * max(skyLightLevels.y, 0.0) * GetMoonPhaseLevel();
        #endif

        return result;
    }

    float GetWaterFogDensity(const in sampler3D tex, const in vec3 worldPos) {
        float sampleDensity1 = texture(tex, worldPos / 96.0).r;
        float sampleDensity2 = texture(tex, worldPos / 16.0).r;
        return 1.0 - 0.6 * sampleDensity1 - 0.3 * sampleDensity2;
    }

    void GetWaterVolumetricLighting(out vec3 scattering, out vec3 transmittance, const in vec2 scatteringF, const in vec3 localViewDir, const in float nearDist, const in float farDist) {
        const float inverseStepCountF = rcp(VL_SAMPLES_WATER + 1);

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

        //vec3 extinctionInv = (1.0 - waterAbsorbColor) * WATER_ABSROPTION_RATE;
        //vec3 fogColorLinear = vec3(1.0); //RGBToLinear(fogColor);

        float skyLight = saturate(eyeBrightnessSmooth.y / 240.0);
        vec3 skyAmbient = GetFancySkyAmbientLight(vec3(0.0, 1.0, 0.0), 1.0);
        vec3 ambient = 1.0 * skyAmbient;// * skyLight;

        vec3 WaterAbsorptionCoefficient = 0.020 * (1.0 - RGBToLinear(waterAbsorbColor));
        vec3 WaterScatteringCoefficient = 0.001 * (RGBToLinear(waterScatterColor));
        vec3 WaterExtinctionCoefficient = WaterScatteringCoefficient + WaterAbsorptionCoefficient;

        #ifndef VL_WATER_NOISE
            float texDensity = 0.5;
        #endif

        scattering = vec3(0.0);
        transmittance = vec3(1.0);
        for (int i = VL_SAMPLES_WATER-1; i > 0; i--) {
            transparentDepth = 1.0;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                shadowPos[0] = shadowClipStart[0] + (i + dither) * shadowClipStep[0];
                shadowPos[1] = shadowClipStart[1] + (i + dither) * shadowClipStep[1];
                shadowPos[2] = shadowClipStart[2] + (i + dither) * shadowClipStep[2];
                shadowPos[3] = shadowClipStart[3] + (i + dither) * shadowClipStep[3];

                int cascade = GetShadowSampleCascade(shadowPos, 0.0);

                const float bias = 0.0; // TODO
                lightSample = CompareOpaqueDepth(shadowPos[cascade], vec2(0.0), bias);

                if (lightSample > EPSILON)
                    transparentDepth = SampleTransparentDepth(shadowPos[cascade].xy, vec2(0.0));

                vec3 traceShadowClipPos = shadowPos[cascade];
            #else
                vec3 traceShadowClipPos = shadowClipStart + shadowClipStep * (i + dither);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    traceShadowClipPos = distort(traceShadowClipPos);
                #endif

                traceShadowClipPos = traceShadowClipPos * 0.5 + 0.5;

                lightSample = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), 0.0);

                if (lightSample > EPSILON)
                    transparentDepth = SampleTransparentDepth(traceShadowClipPos.xy, vec2(0.0));
            #endif

            vec3 traceWorldPos = worldStart + localStep * (i + dither);

            #if defined WORLD_CLOUDS_ENABLED && defined SHADOW_CLOUD
                if (HasClouds(traceWorldPos, localLightDir)) {
                    vec3 cloudPos = GetCloudPosition(traceWorldPos, localLightDir);
                    float cloudF = GetCloudFactor(cloudPos, localLightDir, 0);
                    lightSample *= pow(1.0 - cloudF, 4.0);
                }
            #endif

            #ifdef VL_WATER_NOISE
                #if SHADER_PLATFORM == PLATFORM_IRIS
                    float texDensity = GetWaterFogDensity(texCloudNoise, traceWorldPos);
                #else
                    float texDensity = GetWaterFogDensity(colortex14, traceWorldPos);
                #endif
            #endif


            // float viewDist = localStepLength * (i + dither);
            // float waterFogF = GetWaterFogFactor(0.0, viewDist);
            // texDensity *= max(1.0 - waterFogF, EPSILON);


            vec3 atmosPos = GetAtmospherePosition(traceWorldPos);
            float sampleElevation = length(atmosPos) - groundRadiusMM;

            float waterLightDist = max((traceShadowClipPos.z - transparentDepth) * MaxShadowDist, 0.0);

            //vec3 stepSunTransmittance = exp(-WaterExtinctionCoefficient * waterLightDist); // TODO: 1.0 = density
            vec3 lightColor = scatteringF.x * lightSample * GetScatteredLighting(sampleElevation) + ambient;

            vec3 stepTransmittance = exp(-WaterExtinctionCoefficient * (localStepLength * texDensity + waterLightDist));
            vec3 scatteringIntegral = (1.0 - stepTransmittance) / WaterExtinctionCoefficient * texDensity;

            // TODO: fix scattering for separate sun/moon light!
            scattering += lightColor * (WaterScatteringCoefficient * scatteringIntegral) * transmittance;

            transmittance *= stepTransmittance;
        }
    }
#endif
