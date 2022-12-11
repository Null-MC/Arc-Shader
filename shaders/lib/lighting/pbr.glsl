#ifdef RENDER_VERTEX
    void PbrVertex(const in vec3 viewPos) {
        viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
        tangentW = at_tangent.w;

        #if defined PARALLAX_ENABLED || (WATER_WAVE_TYPE == WATER_WAVE_PARALLAX && (defined RENDER_WATER || defined RENDER_HAND_WATER))
            vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * at_tangent.w);
            mat3 matTBN = mat3(viewTangent, viewBinormal, viewNormal);

            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            localCoord = sign(coordNMid) * 0.5 + 0.5;

            #if defined SHADOW_ENABLED
                tanLightPos = shadowLightPosition * matTBN;
            #endif

            tanViewPos = viewPos * matTBN;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && (defined RENDER_TERRAIN || defined RENDER_WATER)
            ApplyHardCodedMaterials(matF0, matSSS, matSmooth, matEmissive);
        #endif
    }
#endif

#ifdef RENDER_FRAG
    #ifdef SKY_ENABLED
        vec3 GetSkyReflectionColor(const in LightData lightData, const in vec3 localPos, const in vec3 viewDir, const in vec3 reflectDir, const in float rough) {
            vec3 sunColorFinalEye = lightData.sunTransmittanceEye * sunColor * max(lightData.skyLightLevels.x, 0.0);
            vec3 moonColorFinalEye = lightData.moonTransmittanceEye * moonColor * max(lightData.skyLightLevels.y, 0.0);

            #ifdef RENDER_WATER
                if (materialId == MATERIAL_WATER && isEyeInWater == 1) {
                    vec2 waterScatteringF = GetWaterScattering(reflectDir);
                    //vec3 waterLightColor = GetWaterScatterColor(reflectDir, sunColorFinalEye, moonColorFinalEye);
                    vec3 waterFogColor = GetWaterFogColor(reflectDir, sunColorFinalEye, moonColorFinalEye, waterScatteringF);

                    //#if defined SKY_ENABLED && !defined VL_WATER_ENABLED
                    float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
                    vec3 vlColor = waterScatteringF.x * sunColorFinalEye + waterScatteringF.y * moonColorFinalEye;
                    waterFogColor += 0.2 * waterScatterColor * vlColor * pow3(eyeLight);
                    //#endif

                    return waterFogColor;
                }
            #endif

            vec3 localReflectDir = normalize(mat3(gbufferModelViewInverse) * reflectDir);
            vec3 skyColor = GetVanillaSkyLuminance(reflectDir);
            float horizonFogF = 1.0 - abs(localReflectDir.y);

            vec3 starF = GetStarLight(localReflectDir);
            starF *= 1.0 - horizonFogF;
            skyColor += starF * StarLumen;

            vec2 scatteringF = GetVanillaSkyScattering(reflectDir, lightData.skyLightLevels);
            vec3 vlColor = scatteringF.x * sunColorFinalEye + scatteringF.y * moonColorFinalEye;

            #ifndef VL_SKY_ENABLED
                vlColor *= RGBToLinear(fogColor);
            #endif

            skyColor += vlColor;// * (1.0 - horizonFogF);

            vec3 cloudColor = GetCloudColor(lightData.skyLightLevels);
            float cloudF = GetCloudFactor(cameraPosition + localPos, localReflectDir);
            cloudF = mix(cloudF, 0.0, pow(horizonFogF, CLOUD_HORIZON_POWER));
            //cloudF *= 1.0 - rough;
            skyColor = mix(skyColor, cloudColor, cloudF);

            // darken lower horizon
            vec3 downDir = normalize(-upPosition);
            float RoDm = max(dot(reflectDir, downDir), 0.0);

            return skyColor * (1.0 - RoDm);
        }
    #endif

    vec4 PbrLighting2(const in PbrMaterial material, const in LightData lightData, const in vec3 viewPos) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = normalize(viewPos);
        float viewDist = length(viewPos);

        vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

        #ifdef RENDER_DEFERRED
            vec2 screenUV = texcoord;
        #else
            vec2 screenUV = gl_FragCoord.xy / viewSize;
        #endif

        #ifdef SKY_ENABLED
            vec3 sunColorFinalEye = lightData.sunTransmittanceEye * sunColor * max(lightData.skyLightLevels.x, 0.0);
            vec3 moonColorFinalEye = lightData.moonTransmittanceEye * moonColor * max(lightData.skyLightLevels.y, 0.0);

            vec3 sunColorFinal = lightData.sunTransmittance * sunColor * max(lightData.skyLightLevels.x, 0.0);
            vec3 moonColorFinal = lightData.moonTransmittance * moonColor * max(lightData.skyLightLevels.y, 0.0);
            vec3 skyLightColorFinal = (sunColorFinal + moonColorFinal);

            vec3 viewLightDir = normalize(shadowLightPosition);
            float NoL = dot(viewNormal, viewLightDir);

            vec3 halfDir = normalize(viewLightDir + -viewDir);
            float LoHm = max(dot(viewLightDir, halfDir), 0.0);
        #else
            float NoL = 1.0;
            float LoHm = 1.0;
        #endif

        float NoLm = max(NoL, 0.0);
        float NoV = dot(viewNormal, -viewDir);
        float NoVm = max(NoV, 0.0);
        vec3 viewUpDir = normalize(upPosition);

        // float blockLight = saturate((lightData.blockLight - (1.0/16.0 + EPSILON)) / (15.0/16.0));
        // float skyLight = saturate((lightData.skyLight - (1.0/16.0 + EPSILON)) / (15.0/16.0));

        vec3 albedo = material.albedo.rgb;
        float smoothness = material.smoothness;

        #if DEBUG_VIEW == DEBUG_VIEW_WHITEWORLD
            albedo = vec3(1.0);
        #endif

        float rough = 1.0 - smoothness;
        float roughL = max(rough * rough, 0.005);

        float shadow = lightData.parallaxShadow;
        vec3 shadowColor = vec3(1.0);
        float shadowSSS = 0.0;

        #ifdef SKY_ENABLED
            float sssDist = 0.0;

            shadow *= step(EPSILON, lightData.geoNoL);
            shadow *= step(EPSILON, NoL);

            #ifdef SHADOW_CLOUD
                vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;

                float cloudF = GetCloudFactor(cameraPosition + localPos, localLightDir);
                float horizonFogF = pow(1.0 - max(localLightDir.y, 0.0), 2.0);
                float cloudShadow = 1.0 - mix(cloudF, 1.0, horizonFogF);
                skyLightColorFinal *= (0.2 + 0.8 * cloudShadow);
            #endif

            float contactShadow = 1.0;
            float contactLightDist = 0.0;
            #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
                #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                    const float minContactShadowDist = 0.6 * shadowDistance;
                #else
                    const float minContactShadowDist = 0.0;
                #endif

                if (viewDist >= minContactShadowDist) {
                    float contactMinDist = 0.0;
                    contactShadow = GetContactShadow(depthtex1, viewPos, viewLightDir, contactMinDist, contactLightDist);
                }
            #endif

            #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                if (shadow > EPSILON)
                    shadow *= GetShadowing(lightData);

                #ifdef SHADOW_COLOR
                    if (lightData.shadowPos.z - lightData.transparentShadowDepth > lightData.shadowBias)
                        shadowColor = GetShadowColor(lightData.shadowPos.xy);

                    shadowColor = RGBToLinear(shadowColor);
                    skyLightColorFinal *= shadowColor;
                #endif

                #ifdef SSS_ENABLED
                    if (material.scattering > EPSILON) {
                        shadowSSS = GetShadowSSS(lightData, material.scattering, sssDist);
                    }
                #endif
            #else
                shadow = pow2(lightData.skyLight) * lightData.occlusion;
                shadowSSS = pow2(lightData.skyLight) * material.scattering;
            #endif

            #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
                float contactShadowMix = saturate(0.2 * (viewDist - minContactShadowDist));

                #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                    contactShadow = mix(1.0, contactShadow, contactShadowMix);
                #endif

                shadow = min(shadow, contactShadow);
                sssDist = max(sssDist, contactLightDist);

                float maxDist = SSS_MAXDIST * material.scattering;
                float contactSSS = 0.7 * pow2(material.scattering) * max(1.0 - contactLightDist / maxDist, 0.0);
                shadowSSS = mix(shadowSSS, contactSSS, contactShadowMix);
            #endif
        #endif

        float shadowFinal = shadow;

        #ifdef LIGHTLEAK_FIX
            // Make areas without skylight fully shadowed (light leak fix)
            float lightLeakFix = saturate(lightData.skyLight * 15.0);
            shadowFinal *= lightLeakFix;
            shadowSSS *= lightLeakFix;
        #endif

        float skyLight = lightData.skyLight;
        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            // Increase skylight when in direct sunlight
            if (isEyeInWater != 1)
                skyLight = max(skyLight, shadowFinal);
        #endif

        float skyLight2 = pow2(skyLight);
        float skyLight3 = pow3(skyLight);

        vec3 reflectColor = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            vec3 reflectDir = reflect(viewDir, viewNormal);

            if (smoothness > EPSILON) {
                #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
                    vec3 viewPosPrev = (gbufferPreviousModelView * vec4(localPos + cameraPosition - previousCameraPosition, 1.0)).xyz;

                    vec3 localReflectDir = mat3(gbufferModelViewInverse) * reflectDir;
                    vec3 reflectDirPrev = mat3(gbufferPreviousModelView) * localReflectDir;

                    // TODO: move to vertex shader?
                    int maxHdrPrevLod = textureQueryLevels(BUFFER_HDR_PREVIOUS);
                    int lod = int(rough * max(maxHdrPrevLod - EPSILON, 0.0));

                    vec4 roughReflectColor = GetReflectColor(BUFFER_DEPTH_PREV, viewPosPrev, reflectDirPrev, lod);

                    reflectColor = roughReflectColor.rgb * roughReflectColor.a;

                    #ifdef SKY_ENABLED
                        if (roughReflectColor.a + EPSILON < 1.0) {
                            vec3 skyReflectColor = GetSkyReflectionColor(lightData, localPos, viewDir, reflectDir, rough) * skyLight;
                            reflectColor += skyReflectColor * (1.0 - roughReflectColor.a);
                        }
                    #endif
                #elif REFLECTION_MODE == REFLECTION_MODE_SKY && defined SKY_ENABLED
                    reflectColor = GetSkyReflectionColor(lightData, localPos, viewDir, reflectDir, rough) * skyLight;
                #endif
            }
        #endif

        #if defined SKY_ENABLED && defined RSM_ENABLED && defined RENDER_DEFERRED
            #ifdef RSM_UPSCALE
                vec2 rsmViewSize = viewSize / exp2(RSM_SCALE);
                vec3 rsmColor = BilateralGaussianDepthBlurRGB_5x(BUFFER_RSM_COLOR, rsmViewSize, BUFFER_RSM_DEPTH, rsmViewSize, lightData.opaqueScreenDepthLinear, 0.9);
            #else
                vec2 tex = screenUV;
                vec3 rsmColor = textureLod(BUFFER_RSM_COLOR, tex, 0).rgb;
            #endif
        #endif

        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
            vec3 blockLightDiffuse = pow2(lightData.blockLight)*blockLightColor;
        #else
            vec3 blockLightDiffuse = pow3(lightData.blockLight)*blockLightColor;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            vec3 specularTint = GetHCM_Tint(material.albedo.rgb, material.hcm);
        #else
            vec3 specularTint = mix(vec3(1.0), material.albedo.rgb, material.f0);
        #endif

        vec4 final = vec4(albedo, material.albedo.a);
        vec3 ambient = vec3(MinWorldLux);
        vec3 diffuse = albedo * blockLightDiffuse;
        vec3 specular = vec3(0.0);
        float occlusion = lightData.occlusion;
        vec3 waterExtinctionInv = WATER_ABSROPTION_RATE * (1.0 - waterAbsorbColor);

        #if AO_TYPE == AO_TYPE_SS && !defined RENDER_WATER && !defined RENDER_HAND_WATER
            #ifdef SSAO_UPSCALE
                occlusion = BilateralGaussianDepthBlur_9x(BUFFER_AO, 0.5 * viewSize, depthtex0, viewSize, lightData.opaqueScreenDepthLinear, 0.9);
            #else
                occlusion = textureLod(BUFFER_AO, screenUV, 0).r;
            #endif
        #endif

        occlusion *= material.occlusion;

        vec3 iblF = vec3(0.0);
        vec3 iblSpec = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            iblF = GetFresnel(material.albedo.rgb, material.f0, material.hcm, NoVm, roughL);

            if (any(greaterThan(reflectColor, vec3(EPSILON)))) {
                vec2 envBRDF = textureLod(BUFFER_BRDF_LUT, vec2(NoVm, rough), 0).rg;

                #if SHADER_PLATFORM == PLATFORM_IRIS
                    envBRDF = RGBToLinear(vec3(envBRDF, 0.0)).rg;
                #endif

                iblSpec = iblF * envBRDF.r + envBRDF.g;
                iblSpec *= (1.0 - roughL) * reflectColor * occlusion;

                float iblFmax = max(max(iblF.x, iblF.y), iblF.z);
                //final.a += iblFmax * max(1.0 - final.a, 0.0);
                //final.a = min(final.a + iblFmax * exposure * final.a, 1.0);
                final.a = max(final.a, iblFmax);
            }
        #endif

        //return vec4(iblSpec, 1.0);

        #ifdef SKY_ENABLED
            float ambientBrightness = mix(0.8 * skyLight2, 0.95 * skyLight, rainStrength) * SHADOW_BRIGHTNESS;

            // TODO: Doing direct cloud shadows on ambient causes really fucked results
            //       At least needs a heavy blur distribution
            // #ifdef SHADOW_CLOUD
            //     ambientBrightness *= cloudShadow;
            // #endif

            vec3 skyAmbient = GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;

            // vec3 sunColor = lightData.sunTransmittance * sunColor;
            // vec3 skyLightColorFinal = (sunColor + moonColor) * shadowColor;

            bool applyWaterAbsorption = isEyeInWater == 1;

            #ifdef RENDER_WATER
                if (materialId == MATERIAL_WATER) applyWaterAbsorption = false;
            #endif

            if (applyWaterAbsorption) {
                vec3 sunAbsorption = exp(-max(lightData.waterShadowDepth, 0.0) * waterExtinctionInv);

                //const vec3 extinctionInv = 1.0 - WATER_ABSORB_COLOR;
                //if (lightData.waterShadowDepth < EPSILON) absorption = vec3(0.0);

                //skyAmbient *= skyLight3;

                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    if (lightData.geoNoL < 0.0 || lightData.opaqueShadowDepth < lightData.shadowPos[lightData.opaqueShadowCascade].z - lightData.shadowBias[lightData.opaqueShadowCascade])
                        shadowAbsorption = vec3(0.0);
                #else
                    if (lightData.geoNoL < 0.0 || lightData.opaqueShadowDepth < lightData.shadowPos.z - lightData.shadowBias)
                        sunAbsorption = 1.0 - (1.0 - sunAbsorption) * (1.0 - SHADOW_BRIGHTNESS);
                #endif

                vec3 viewAbsorption = exp(-max(lightData.opaqueScreenDepthLinear, 0.0) * waterExtinctionInv);

                vec3 absorption = sunAbsorption * viewAbsorption;

                skyAmbient *= absorption;
                skyLightColorFinal *= absorption;// * skyLight3;
                //reflectColor *= absorption;
                iblSpec *= absorption;

                #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    // sample normal, get fresnel, darken
                    uint shadowData = textureLod(shadowcolor1, lightData.shadowPos.xy, 0).g;
                    vec3 waterNormal = unpackUnorm4x8(shadowData).xyz;
                    waterNormal = normalize(waterNormal * 2.0 - 1.0);
                    float water_NoL = max(waterNormal.z, 0.0);
                    float water_F = F_schlick(water_NoL, 0.02, 1.0);

                    water_F = 1.0 - water_F;
                    //water_F = smoothstep(0.5, 1.0, 1.0 - water_F);

                    skyLightColorFinal *= max(water_F, 0.0);
                #endif
            }

            ambient += skyAmbient;

            //LoHm = min(LoHm * 1.2, 1.0);
            vec3 sunF = GetFresnel(material.albedo.rgb, material.f0, material.hcm, LoHm, roughL);
            //sunF = min(sunF * 1.1, 1.0);

            vec3 sunDiffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL);
            sunDiffuse *= skyLightColorFinal * shadowFinal * max(1.0 - sunF, 0.0);// * skyLight2;

            #if defined SSS_ENABLED && defined SKY_ENABLED
                if (material.scattering > 0.0 && shadowSSS > 0.0) {
                    vec3 sssAlbedo = material.albedo.rgb;

                    #ifdef SSS_NORMALIZE_ALBEDO
                        if (all(lessThan(sssAlbedo, vec3(EPSILON)))) albedo = vec3(1.0);
                        albedo = normalize(albedo);
                    #endif

                    //vec3 halfDirInverse = normalize(-viewLightDir + -viewDir);
                    //float LoHmInverse = max(dot(-viewLightDir, halfDirInverse), 0.0);
                    //float NoLmInverse = max(dot(-viewNormal, viewLightDir), 0.0);
                    //float sunFInverse = F_SchlickRoughness(f0, NoLmInverse, roughL);
                    vec3 sssLightColor = shadowSSS * skyLightColorFinal;// * max(1.0 - sunFInverse, 0.0);
                    
                    float VoL = dot(viewDir, viewLightDir);
                    float inScatter = ComputeVolumetricScattering(VoL, 0.16);
                    // vec3 inLightColor = sssLightColor * sssAlbedo * max(inScatter, 0.0);

                    //float outScatter = ComputeVolumetricScattering(VoL, mix(0.3, -0.1, material.scattering));
                    //vec3 outLightColor = max(outScatter, 0.0) * sssLightColor * pow(sssAlbedo, vec3(2.0));

                    //vec3 sssDiffuseLight = inLightColor;// + outLightColor;//* max(-NoL, 0.0);

                    sssDist = max(sssDist / (shadowSSS * SSS_MAXDIST), 0.0001);
                    vec3 sssExt = CalculateExtinction(material.albedo.rgb, sssDist);
                    //return vec4(sssExt * sssLightColor, 1.0);

                    vec3 sssDiffuseLight = sssLightColor * sssExt * saturate(3.0 * inScatter);

                    sssDiffuseLight += GetSkyAmbientLight(lightData, viewDir) * ambientBrightness * occlusion * skyLight2;

                    sssDiffuseLight *= sssAlbedo * material.scattering;

                    //sunDiffuse = GetDiffuseBSDF(sunDiffuse, sssDiffuseLight, material.scattering, NoVm, NoLm, LoHm, roughL);
                    sunDiffuse += sssDiffuseLight * NoVm * (0.01 * SSS_STRENGTH);
                }
            #endif

            diffuse += sunDiffuse;

            if (NoLm > EPSILON) {
                float NoHm = max(dot(viewNormal, halfDir), 0.0);

                vec3 sunSpec = GetSpecularBRDF(sunF, NoVm, NoLm, NoHm, roughL) * skyLightColorFinal * skyLight2 * shadowFinal;// * final.a;
                
                specular += sunSpec;// * material.albedo.a;

                final.a = min(final.a + luminance(sunSpec) * exposure, 1.0);
            }
        #endif

        #if !defined WORLD_NETHER && !defined WORLD_END
            vec2 waterScatteringF = GetWaterScattering(viewDir);
        #endif
    
        #if defined RENDER_WATER && !defined WORLD_NETHER && !defined WORLD_END
            if (materialId == MATERIAL_WATER) {
                #if WATER_REFRACTION != WATER_REFRACTION_NONE
                    float waterRefractEta = isEyeInWater == 1
                        ? IOR_WATER / IOR_AIR
                        : IOR_AIR / IOR_WATER;
                    
                    vec3 refractDir = refract(viewDir, viewNormal, waterRefractEta);

                    float refractOpaqueScreenDepth = lightData.opaqueScreenDepth;
                    float refractOpaqueScreenDepthLinear = lightData.opaqueScreenDepthLinear;
                    vec3 refractColor = vec3(0.0);
                    vec2 refractUV = screenUV;

                    //float outNoL = max(dot(-viewNormal, -refractDir), 0.0);
                    //float outF = 0.0;//F_schlick(outNoL, 0.02, 1.0);

                    if (dot(refractDir, refractDir) > EPSILON) {
                        #if REFRACTION_STRENGTH > 0
                            float refractDist = max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0);

                            #if WATER_REFRACTION == WATER_REFRACTION_FANCY
                                vec3 refractClipPos = unproject(gbufferProjection * vec4(viewPos + refractDir, 1.0)) * 0.5 + 0.5;
                                
                                vec2 refractOffset = refractClipPos.xy - screenUV;

                                refractOffset *= 16.0 * saturate(0.5 * refractDist);
                                refractUV += refractOffset * 0.01 * REFRACTION_STRENGTH;
                                
                                vec2 alphaXY = saturate(10.0 * abs(vec2(0.5) - refractUV) - 4.0);
                                float rf = smoothstep(0.0, 1.0, 1.0 - maxOf(alphaXY));
                                refractUV = mix(screenUV, refractUV, rf);
                            #else
                                vec2 stepSize = rcp(viewSize) * REFRACTION_STRENGTH;
                                refractUV -= (viewNormal.xz - vec2(0.0, 0.5)) * stepSize * saturate(refractDist);
                            #endif

                            refractOpaqueScreenDepth = textureLod(depthtex1, refractUV, 0).r;
                            refractOpaqueScreenDepthLinear = linearizeDepthFast(refractOpaqueScreenDepth, near, far);

                            #if WATER_REFRACTION == WATER_REFRACTION_FANCY
                                //vec2 startUV = refractUV;
                                // vec2 d = refractUV - screenUV;
                                // vec2 dp = d * viewSize;

                                // float stepCount = abs(dp.x) > abs(dp.y) ? abs(dp.x) : abs(dp.y);

                                // if (stepCount > 1.0) {
                                //     vec2 step = d / stepCount;

                                //     float traceDepth = 0.0;
                                //     for (int i = 0; i <= stepCount && traceDepth < waterSolidDepthFinal.x; i++) {
                                //         refractUV = screenUV + i * step;
                                //         refractOpaqueScreenDepth = textureLod(depthtex1, refractUV, 0).r;
                                //         refractOpaqueScreenDepthLinear = linearizeDepthFast(refractOpaqueScreenDepth, near, far);
                                //     }

                                //     //solidViewDepthLinear = solidViewDepth;//linearizeDepthFast(solidViewDepth, near, far);
                                // }
                            #else
                                if (refractOpaqueScreenDepthLinear < lightData.transparentScreenDepthLinear) {
                                    // reset UV & depths to original point
                                    refractUV = screenUV;
                                    //refractUV = (refractUV + screenUV) * 0.5;
                                    refractOpaqueScreenDepth = lightData.opaqueScreenDepth;
                                    refractOpaqueScreenDepthLinear = lightData.opaqueScreenDepthLinear;
                                }
                            #endif
                        #endif

                        #ifdef WATER_REFRACT_HACK
                            ivec2 iuv = ivec2(refractUV * viewSize);
                            refractColor = texelFetch(BUFFER_HDR, iuv, 0).rgb / exposure;
                        #else
                            refractColor = textureLod(BUFFER_REFRACT, refractUV, 0).rgb / exposure;
                        #endif
                    }
                    else {
                        // TIR
                        refractUV = screenUV;
                        refractOpaqueScreenDepth = lightData.transparentScreenDepth;
                        refractOpaqueScreenDepthLinear = lightData.transparentScreenDepthLinear;
                        //refractColor = vec3(10000.0, 0.0, 0.0);

                        if (isEyeInWater == 1) {
                            iblSpec = (1.0 - roughL) * reflectColor;
                        }
                    }

                    float waterViewDepthFinal;// = isEyeInWater == 1 ? lightData.transparentScreenDepthLinear
                    //    : max(refractOpaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0);

                    if (isEyeInWater == 1) {
                        waterViewDepthFinal = viewDist;
                    }
                    else {
                        //float shit = max(refractOpaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0);
                        //float shit2 = delinearizeDepthFast(shit, near, far);
                        vec3 waterOpaqueViewPos = unproject(gbufferProjectionInverse * vec4(vec3(refractUV, refractOpaqueScreenDepth) * 2.0 - 1.0, 1.0));
                        waterViewDepthFinal = max(length(waterOpaqueViewPos) - viewDist, 0.0);
                    }

                    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                        vec3 waterOpaqueClipPos = vec3(refractUV, refractOpaqueScreenDepth) * 2.0 - 1.0;
                        vec3 waterOpaqueLocalPos = unproject(gbufferModelViewInverse * (gbufferProjectionInverse * vec4(waterOpaqueClipPos, 1.0)));
                        vec3 waterOpaqueShadowPos = (shadowProjection * (shadowModelView * vec4(waterOpaqueLocalPos, 1.0))).xyz;

                        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                            waterOpaqueShadowPos = distort(waterOpaqueShadowPos);
                        #endif

                        waterOpaqueShadowPos = waterOpaqueShadowPos * 0.5 + 0.5;

                        #ifdef SHADOW_DITHER
                            float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
                            waterOpaqueShadowPos.xy += ditherOffset;
                        #endif

                        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                            float ShadowMaxDepth = far * 3.0;

                            // float waterOpaqueShadowDepth = GetNearestOpaqueDepth(vec4(waterOpaqueShadowPos, 1.0), vec2(0.0));
                            // float waterTransparentShadowDepth = GetNearestTransparentDepth(vec4(waterOpaqueShadowPos, 1.0), vec2(0.0));
                            // TODO: This should be using the lines above, but that requires calulcating waterShadowPos 4x!
                            float waterOpaqueShadowDepth = SampleOpaqueDepth(waterOpaqueShadowPos.xy, vec2(0.0));
                            float waterTransparentShadowDepth = SampleTransparentDepth(waterOpaqueShadowPos.xy, vec2(0.0));
                        #else
                            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                                const float ShadowMaxDepth = 512.0;
                            #else
                                const float ShadowMaxDepth = 256.0;
                            #endif

                            float waterOpaqueShadowDepth = SampleOpaqueDepth(vec4(waterOpaqueShadowPos, 1.0), vec2(0.0));
                            float waterTransparentShadowDepth = SampleTransparentDepth(vec4(waterOpaqueShadowPos, 1.0), vec2(0.0));
                        #endif

                        float waterShadowDepth = max(waterOpaqueShadowPos.z - waterTransparentShadowDepth, 0.0) * ShadowMaxDepth;
                    #else
                        const float waterShadowDepth = 0.0;
                    #endif

                    //float waterLightDist = max(waterShadowDepth + waterViewDepthFinal, EPSILON);

                    //uvec4 deferredData = texelFetch(BUFFER_DEFERRED, ivec2(gl_FragCoord.xy), 0);
                    //vec4 waterLightingMap = unpackUnorm4x8(deferredData.a);
                    float waterGeoNoL = 1.0;//waterLightingMap.z * 2.0 - 1.0; //lightData.geoNoL;

                    // TODO: This should be based on the refracted opaque fragment!
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        float waterShadowBias = lightData.shadowBias[lightData.transparentShadowCascade];
                    #else
                        float waterShadowBias = lightData.shadowBias;
                    #endif

                    vec3 sunAbsorption = exp(-waterShadowDepth * waterExtinctionInv);
                    vec3 viewAbsorption = exp(-waterViewDepthFinal * waterExtinctionInv);

                    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                        if (waterGeoNoL <= 0.0 || waterOpaqueShadowDepth < waterOpaqueShadowPos.z - waterShadowBias)
                            sunAbsorption = 1.0 - (1.0 - sunAbsorption) * (1.0 - SHADOW_BRIGHTNESS);
                    #endif

                    refractColor *= sunAbsorption * viewAbsorption;

                    refractColor *= max(1.0 - sunF, 0.0);

                    if (isEyeInWater != 1) {
                        //vec2 waterScatteringF = GetWaterScattering(viewDir);
                        vec3 waterFogColor = GetWaterFogColor(viewDir, sunColorFinalEye, moonColorFinalEye, waterScatteringF);
                        ApplyWaterFog(refractColor, waterFogColor, waterViewDepthFinal);

                        #ifdef VL_WATER_ENABLED
                            //if (lightData.transparentScreenDepthLinear < refractOpaqueScreenDepthLinear) {
                                float dist = waterFogDistSmooth;
                                //if (refractOpaqueScreenDepthLinear < 1.0 - EPSILON && lightData.transparentScreenDepthLinear < 1.0 - EPSILON)
                                //    dist = clamp(refractOpaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0, waterFogDistSmooth);

                                vec3 farViewPos = viewPos + viewDir * dist;

                                refractColor += GetWaterVolumetricLighting(lightData, viewPos, farViewPos, waterScatteringF);
                            //}
                        #endif
                    }
                    
                    // TODO: refract out shadowing
                    refractColor *= max(1.0 - iblF, 0.0);

                    #ifndef WATER_FANCY
                        refractColor = mix(refractColor, diffuse, material.albedo.a);
                    #endif

                    diffuse = refractColor;
                    final.a = saturate(10.0*waterViewDepthFinal - 0.2);
                    //final.a = 1.0;
                #else
                    float waterViewDepth = isEyeInWater == 1 ? lightData.transparentScreenDepthLinear
                        : max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0);

                    float waterLightDist = waterViewDepth + lightData.waterShadowDepth;

                    vec3 absorption = exp(-waterViewDepth * waterExtinctionInv);
                    vec3 refractColor = diffuse * absorption;

                    float lightDist = isEyeInWater == 1
                        ? min(lightData.opaqueScreenDepthLinear, lightData.transparentScreenDepthLinear)
                        : lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear;

                    //vec3 waterLightColor = GetWaterScatterColor(viewDir, lightData.sunTransmittanceEye);
                    //vec2 waterScatteringF = GetWaterScattering(viewDir);
                    vec3 waterFogColor = GetWaterFogColor(viewDir, sunColorFinalEye, moonColorFinalEye, waterScatteringF);
                    float waterFogF = ApplyWaterFog(refractColor, waterFogColor, lightDist);
                    
                    refractColor *= max(1.0 - iblF, 0.0);

                    #ifndef WATER_FANCY
                        refractColor = mix(refractColor, diffuse, material.albedo.a);
                    #endif

                    diffuse = refractColor;
                    final.a = min(final.a + waterFogF, 1.0);// * (1.0 - material.albedo.a);// * max(1.0 - final.a, 0.0);
                #endif

                ambient = vec3(0.0);
                //return vec4(reflectColor, 1.0);
            }
        #endif

        #if defined HANDLIGHT_ENABLED
            if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
                vec3 handDiffuse, handSpecular;
                ApplyHandLighting(handDiffuse, handSpecular, material.albedo.rgb, material.f0, material.hcm, material.scattering, viewNormal, viewPos.xyz, -viewDir, NoVm, roughL);

                #ifdef RENDER_WATER
                    if (materialId != MATERIAL_WATER) {
                #endif

                    diffuse += handDiffuse;
                    final.a = min(final.a + luminance(handSpecular) * exposure, 1.0);

                #ifdef RENDER_WATER
                    }
                #endif

                specular += handSpecular;
            }
        #endif

        #ifdef SKY_ENABLED
            #if SHADER_PLATFORM == PLATFORM_IRIS
                //if (lightningBoltPosition.w > EPSILON)
                //    ApplyLightning(diffuse, specular, material.albedo.rgb, material.f0, material.hcm, material.scattering, viewNormal, viewPos.xyz, -viewDir, NoVm, roughL);
            #endif

            #if defined RSM_ENABLED && defined RENDER_DEFERRED
                ambient += rsmColor * skyLightColorFinal;
            #endif
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            if (material.hcm >= 0) {
                float metalDarkF = roughL * METAL_AMBIENT; //1.0 - material.f0 * (1.0 - METAL_AMBIENT);
                diffuse *= metalDarkF;
                ambient *= metalDarkF;
            }
        #else
            float metalDarkF = mix(roughL * METAL_AMBIENT, 1.0, 1.0 - pow2(material.f0));
            diffuse *= metalDarkF;
            ambient *= metalDarkF;
        #endif

        vec3 emissive = material.albedo.rgb * pow(material.emission, 2.2) * EmissionLumens;

        //occlusion *= SHADOW_BRIGHTNESS;

        final.rgb = final.rgb * (ambient * occlusion)
            + diffuse + emissive
            + (specular + iblSpec) * specularTint;

        float fogFactor;
        if (isEyeInWater == 1) {
            //vec3 sunColorFinal = lightData.sunTransmittanceEye * sunColor;
            //vec3 moonColorFinal = lightData.moonTransmittanceEye * moonColor;

            #ifdef SKY_ENABLED
                //vec2 waterScatteringF = GetWaterScattering(viewDir);
                vec3 waterFogColor = GetWaterFogColor(viewDir, sunColorFinalEye, moonColorFinalEye, waterScatteringF);
            #else
                vec3 waterFogColor = vec3(0.0);
            #endif

            ApplyWaterFog(final.rgb, waterFogColor, viewDist);

            #if defined SKY_ENABLED && defined VL_WATER_ENABLED
                vec3 nearViewPos = viewDir * near;
                vec3 farViewPos = viewDir * min(viewDist, waterFogDistSmooth);

                final.rgb += GetWaterVolumetricLighting(lightData, nearViewPos, farViewPos, waterScatteringF);
            #endif
        }
        else {
            #if !defined SKY_ENABLED || !defined VL_SKY_ENABLED
                final.rgb *= exp(-ATMOS_EXTINCTION * viewDist);
            #endif
        }

        return final;
    }
#endif
