const float AirSpeed = 20.0;


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

    vec3 GetVolumetricLighting(const in LightData lightData, inout vec3 transmittance, const in vec3 nearViewPos, const in vec3 farViewPos) {
        const float inverseStepCountF = rcp(VL_SAMPLES_SKY + 1);
        
        #ifdef VL_DITHER
            float dither = Bayer16(gl_FragCoord.xy);
        #else
            const float dither = 0.0;
        #endif

        vec3 localStart = (gbufferModelViewInverse * vec4(nearViewPos, 1.0)).xyz;
        vec3 localEnd = (gbufferModelViewInverse * vec4(farViewPos, 1.0)).xyz;
        vec3 localRay = localEnd - localStart;
        float localRayLength = length(localRay);
        vec3 localStep = localRay * inverseStepCountF;

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
        
        //#ifdef SHADOW_CLOUD
            vec3 localLightDir = GetShadowLightLocalDir();
            vec3 viewLightDir = mat3(gbufferModelView) * localLightDir;
            vec3 localSunDir = GetSunLocalDir();
        //#endif

        float time = frameTimeCounter / 3600.0;
        //vec3 shadowMax = 1.0 - vec3(vec2(shadowPixelSize), EPSILON);
        float minFogF = min(VLFogMinF * (1.0 + 0.6 * max(lightData.skyLightLevels.x, 0.0)), 1.0);

        #ifndef VL_FOG_NOISE
            #ifdef WORLD_END
                const float texDensity = 9.6;
            #else
                const float texDensity = 1.0;//mix(1.0, 2.8, rainStrength);
            #endif
        #endif

        vec3 viewDir = normalize(farViewPos - nearViewPos);
        float VoL = dot(viewLightDir, viewDir);
        float miePhaseValue = getMiePhase(VoL);
        float rayleighPhaseValue = getRayleighPhase(-VoL);

        const float atmosScale = (atmosphereRadiusMM - groundRadiusMM) / (ATMOSPHERE_LEVEL - SEA_LEVEL);

        vec3 sunColorSky = SunLux * GetSunColor();

        #ifdef WORLD_MOON_ENABLED
            vec3 moonColorSky = MoonLux * GetMoonColor();
        #endif

        vec3 scattering = vec3(0.0);
        for (int i = 1; i < VL_SAMPLES_SKY; i++) {
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos[4];
                shadowPos[0] = shadowClipStart[0] + (i + dither) * shadowClipStep[0];
                shadowPos[1] = shadowClipStart[1] + (i + dither) * shadowClipStep[1];
                shadowPos[2] = shadowClipStart[2] + (i + dither) * shadowClipStep[2];
                shadowPos[3] = shadowClipStart[3] + (i + dither) * shadowClipStep[3];

                int cascade = GetShadowSampleCascade(shadowPos, 0.0);
                vec3 traceShadowClipPos = shadowPos[cascade];

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

                float sampleF = CompareOpaqueDepth(traceShadowClipPos, vec2(0.0), lightData.shadowBias);
            #endif

            vec3 traceWorldPos = worldStart + localStep * (i + dither);

            #if defined WORLD_CLOUDS_ENABLED && defined SHADOW_CLOUD
                float cloudF = GetCloudFactor(traceWorldPos, localLightDir, 0);
                sampleF *= pow(1.0 - cloudF, 2.0);
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
                vec3 sunTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.x) * sunColorSky;
            #else
                vec3 sunTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.x) * sunColorSky;
            #endif

            vec3 lightTransmittance = sunTransmittance;

            #ifdef WORLD_MOON_ENABLED
                #if SHADER_PLATFORM == PLATFORM_IRIS
                    vec3 moonTransmittance = GetTransmittance(texSunTransmittance, sampleElevation, skyLightLevels.y) * moonColorSky;
                #else
                    vec3 moonTransmittance = GetTransmittance(colortex12, sampleElevation, skyLightLevels.y) * moonColorSky;
                #endif

                lightTransmittance += moonTransmittance;
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

        return scattering;
    }
#endif

#ifdef VL_WATER_ENABLED
    vec3 GetScatteredLighting(const in float elevation, const in vec2 skyLightLevels, const in vec2 scatteringF) {
        #if SHADER_PLATFORM == PLATFORM_IRIS
            vec3 sunTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.x);
        #else
            vec3 sunTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.x);
        #endif

        vec3 result = scatteringF.x * sunTransmittance * sunColor * max(skyLightLevels.x, 0.0);

        #ifdef WORLD_MOON_ENABLED
            #if SHADER_PLATFORM == PLATFORM_IRIS
                vec3 moonTransmittance = GetTransmittance(texSunTransmittance, elevation, skyLightLevels.y);
            #else
                vec3 moonTransmittance = GetTransmittance(colortex12, elevation, skyLightLevels.y);
            #endif

            result += scatteringF.y * moonTransmittance * GetMoonPhaseLevel() * moonColor * max(skyLightLevels.y, 0.0);
        #endif

        return result;
    }

    float GetWaterFogDensity(const in sampler3D tex, const in vec3 worldPos) {
        float sampleDensity1 = texture(tex, worldPos / 96.0).r;
        float sampleDensity2 = texture(tex, worldPos / 16.0).r;
        return 1.0 - 0.6 * sampleDensity1 - 0.3 * sampleDensity2;
    }

    vec3 GetWaterVolumetricLighting(const in LightData lightData, const in vec3 nearViewPos, const in vec3 farViewPos, const in vec2 scatteringF) {
        const float inverseStepCountF = rcp(VL_SAMPLES_WATER + 1);

        #ifdef SHADOW_CLOUD
            vec3 localLightDir = GetShadowLightLocalDir();
            if (localLightDir.y <= 0.0) return vec3(0.0);
        #endif

        #ifdef VL_DITHER
            float dither = Bayer16(gl_FragCoord.xy);
        #else
            const float dither = 0.0;
        #endif

        vec3 localStart = (gbufferModelViewInverse * vec4(nearViewPos, 1.0)).xyz;
        vec3 localEnd = (gbufferModelViewInverse * vec4(farViewPos, 1.0)).xyz;
        vec3 localRay = localEnd - localStart;
        float localRayLength = length(localRay);
        vec3 localStep = localRay * inverseStepCountF;

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

                int cascade = GetShadowSampleCascade(shadowPos, 0.0);

                lightSample = CompareOpaqueDepth(shadowPos[cascade], vec2(0.0), lightData.shadowBias[cascade]);

                int waterOpaqueCascade = -1;
                if (lightSample > EPSILON)
                    transparentDepth = GetNearestTransparentDepth(shadowPos, vec2(0.0), waterOpaqueCascade);

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

            #if defined WORLD_CLOUDS_ENABLED && defined SHADOW_CLOUD
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
            // uint data = textureLod(shadowcolor1, traceShadowClipPos.xy, 0).g;
            // vec3 normal = unpackUnorm4x8(data).xyz;
            // normal = normalize(normal * 2.0 - 1.0);
            // float NoL = max(normal.z, 0.0);
            // float waterF = F_schlick(NoL, 0.02, 1.0);

            #ifdef VL_WATER_NOISE
                // float sampleDensity1 = texture(colortex14, traceWorldPos / 96.0).r;
                // float sampleDensity2 = texture(colortex14, traceWorldPos / 16.0).r;
                // lightSample *= 1.0 - 0.6 * sampleDensity1 - 0.3 * sampleDensity2;

                #if SHADER_PLATFORM == PLATFORM_IRIS
                    lightSample *= GetWaterFogDensity(texCloudNoise, traceWorldPos);
                #else
                    lightSample *= GetWaterFogDensity(colortex14, traceWorldPos);
                #endif
            #endif

            accumF += lightSample * lightColor;// * max(1.0 - waterF, 0.0);
        }

        return (accumF / VL_SAMPLES_WATER) * localRayLength * VL_WATER_DENSITY;
    }
#endif
