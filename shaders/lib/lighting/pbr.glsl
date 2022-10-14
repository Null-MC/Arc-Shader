#ifdef RENDER_VERTEX
    //flat out bool isMissingTangent;

    void PbrVertex(const in vec3 viewPos) {
        //bool isMissingTangent = any(isnan(at_tangent));

        //if (!isMissingTangent) {
            //vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
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
        //}
        //else {
        //    viewTangent = vec3(0.0);
        //}

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && (defined RENDER_TERRAIN || defined RENDER_WATER)
            ApplyHardCodedMaterials();
        #endif
    }
#endif

#ifdef RENDER_FRAG
    #ifdef RENDER_WATER
        float GetWaterDepth(const in vec2 screenUV) {
            float waterViewDepthLinear = linearizeDepthFast(gl_FragCoord.z, near, far);
            if (isEyeInWater == 1) return waterViewDepthLinear;

            float solidViewDepth = textureLod(depthtex1, screenUV, 0).r;
            float solidViewDepthLinear = linearizeDepthFast(solidViewDepth, near, far);
            return max(solidViewDepthLinear - waterViewDepthLinear, 0.0);
        }

        // returns: x=water-depth, y=solid-depth
        vec2 GetWaterSolidDepth(const in vec2 screenUV) {
            float solidViewDepth = textureLod(depthtex1, screenUV, 0).r;
            float solidViewDepthLinear = linearizeDepthFast(solidViewDepth, near, far);
            float waterViewDepthLinear = linearizeDepthFast(gl_FragCoord.z, near, far);

            return vec2(waterViewDepthLinear, solidViewDepthLinear);
        }
    #endif

    #ifdef SKY_ENABLED
        vec3 GetSkyReflectionColor(const in LightData lightData, const in vec3 reflectDir) {
            if (isEyeInWater == 1) return WATER_COLOR.rgb;

            // darken lower horizon
            vec3 downDir = normalize(-upPosition);
            float RoDm = max(dot(reflectDir, downDir), 0.0);
            float reflectF = 1.0 - RoDm;

            // occlude inward reflections
            //float NoRm = max(dot(reflectDir, -viewNormal), 0.0);
            //reflectF *= 1.0 - pow(NoRm, 0.5);

            vec3 skyColor = GetVanillaSkyLuminance(reflectDir);

            #ifdef VL_ENABLED
                //float skyLumen = luminance(skyColor);

                vec3 sunColor = lightData.sunTransmittance * GetSunLux(); // * sunColor;
                skyColor += GetVanillaSkyScattering(reflectDir, lightData.skyLightLevels, sunColor, moonColor);

                //setLuminance(skyColor, skyLumen);
            #endif

            return skyColor * reflectF;
        }
    #endif

    #if defined SKY_ENABLED && defined RSM_ENABLED && defined RSM_UPSCALE && defined RENDER_DEFERRED
        vec3 GetUpscaledRSM(const in LightData lightData, const in vec3 shadowViewPos, const in vec3 shadowViewNormal, const in float depthLinear, const in vec2 screenUV) {
            vec4 rsmDepths = textureGather(BUFFER_RSM_DEPTH, screenUV, 0);
            float rsmDepthMin = min(min(rsmDepths.x, rsmDepths.y), min(rsmDepths.z, rsmDepths.w));
            float rsmDepthMax = max(max(rsmDepths.x, rsmDepths.y), max(rsmDepths.z, rsmDepths.w));

            float rsmDepthMinLinear = linearizeDepth(rsmDepthMin * 2.0 - 1.0, near, far);
            float rsmDepthMaxLinear = linearizeDepth(rsmDepthMax * 2.0 - 1.0, near, far);

            // TODO: Not sure if this should be negative or not!
            //float clipDepthLinear = -viewPos.z; //linearizeDepth(clipDepth * 2.0 - 1.0, near, far);
            float depthThreshold = 0.01 + 0.018 * pow2(depthLinear);

            bool depthTest = abs(rsmDepthMinLinear - depthLinear) <= depthThreshold
                          && abs(rsmDepthMaxLinear - depthLinear) <= depthThreshold;

            if (depthTest) {
                return textureLod(BUFFER_RSM_COLOR, screenUV, 0).rgb;
            }
            else {
                vec3 final = vec3(0.0);
                #ifdef LIGHTLEAK_FIX
                    if (lightData.skyLight >= 1.0 / 16.0) {
                #endif
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        final = GetIndirectLighting_RSM(lightData.matShadowProjection, shadowViewPos, shadowViewNormal);
                    #else
                        final = GetIndirectLighting_RSM(shadowViewPos, shadowViewNormal);
                    #endif
                #ifdef LIGHTLEAK_FIX
                    }
                #endif

                //final = mix(final, vec3(600.0, 0.0, 0.0), 0.25);
                return final;
            }
        }
    #endif

    vec4 PbrLighting2(const in PbrMaterial material, const in LightData lightData, const in vec3 viewPos) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = -normalize(viewPos);
        float viewDist = length(viewPos);

        vec2 screenUV = gl_FragCoord.xy / viewSize;

        #ifdef SHADOW_ENABLED
            vec3 viewLightDir = normalize(shadowLightPosition);
            float NoL = dot(viewNormal, viewLightDir);

            vec3 halfDir = normalize(viewLightDir + viewDir);
            float LoHm = max(dot(viewLightDir, halfDir), 0.0);
        #else
            float NoL = 1.0;
            float LoHm = 1.0;
        #endif

        float NoLm = max(NoL, 0.0);
        float NoVm = max(dot(viewNormal, viewDir), 0.0);
        vec3 viewUpDir = normalize(upPosition);

        float blockLight = saturate((lightData.blockLight - (1.0/16.0 + EPSILON)) / (15.0/16.0));
        float skyLight = saturate((lightData.skyLight - (1.0/16.0 + EPSILON)) / (15.0/16.0));

        vec3 albedo = material.albedo.rgb;
        float smoothness = material.smoothness;
        float f0 = material.f0;

        #if defined SKY_ENABLED
            float wetnessFinal = GetDirectionalWetness(viewNormal, skyLight);

            #ifdef RENDER_WATER
                if (materialId != 1) {
            #endif
                if (wetnessFinal > EPSILON) {
                    vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
                    float noiseHigh = 1.0 - textureLod(noisetex, 0.24*localPos.xz, 0).r;
                    float noiseLow = 1.0 - textureLod(noisetex, 0.03*localPos.xz, 0).r;

                    float shit = 0.78*wetnessFinal;
                    wetnessFinal = smoothstep(0.0, 1.0, wetnessFinal);
                    wetnessFinal *= (1.0 - noiseHigh * noiseLow) * (1.0 - shit) + shit;

                    albedo *= GetWetnessDarkening(wetnessFinal, material.porosity);

                    float surfaceWetness = GetSurfaceWetness(wetnessFinal, material.porosity);
                    smoothness = mix(smoothness, WATER_SMOOTH, surfaceWetness);
                    f0 = mix(f0, 0.02, surfaceWetness * (1.0 - f0));
                }
            #ifdef RENDER_WATER
                }
            #endif
        #endif

        float rough = 1.0 - smoothness;
        float roughL = max(rough * rough, 0.005);

        float shadow = lightData.parallaxShadow;
        vec3 shadowColor = vec3(1.0);
        //float opaqueShadowDepth = 1.0;
        float shadowSSS = 0.0;

        #ifdef SKY_ENABLED
            //vec2 skyLightLevels = GetSkyLightLevels();
            float sunLightLevel = GetSunLightLevel(lightData.skyLightLevels.x);
            float sssDist = 0.0;

            shadow *= step(EPSILON, lightData.geoNoL);
            shadow *= step(EPSILON, NoL);

            float contactShadow = 1.0;
            #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
                if (shadow > EPSILON) {
                    vec3 shadowRay = viewLightDir * 10.0;
                    contactShadow = GetContactShadow(depthtex1, viewPos, shadowRay);
                }
                else contactShadow = 0.0;
            #endif

            #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                bool isInBounds = lightData.opaqueShadowDepth < 1.0 - EPSILON;

                if (isInBounds) {
                    if (shadow > EPSILON)
                        shadow *= GetShadowing(lightData);

                    #ifdef SHADOW_COLOR
                        shadowColor = GetShadowColor(lightData);
                        shadowColor = RGBToLinear(shadowColor);
                    #endif

                    #ifdef SSS_ENABLED
                        if (material.scattering > EPSILON) {
                            shadowSSS = GetShadowSSS(lightData, material.scattering, sssDist);
                            // TODO: use depth for extinction
                        }
                    #endif

                    #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                        contactShadow = 1.0;
                    #endif
                }

                if (shadowSSS >= 1.0 - EPSILON) shadowSSS = 0.0;
            #else
                shadow = pow2(skyLight) * lightData.occlusion;
                shadowSSS = pow2(skyLight) * material.scattering;
            #endif

            #if SHADOW_CONTACT != 0
                shadow = min(shadow, contactShadow);
            #endif
        #endif

        float shadowFinal = shadow;

        #ifdef LIGHTLEAK_FIX
            // Make areas without skylight fully shadowed (light leak fix)
            float lightLeakFix = step(skyLight, EPSILON);
            shadowFinal *= lightLeakFix;
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            // Increase skylight when in direct sunlight
            skyLight = max(skyLight, shadowFinal);
        #endif

        float skyLight2 = pow2(skyLight);
        float skyLight3 = pow3(skyLight);

        vec3 reflectColor = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            vec3 reflectDir = reflect(-viewDir, viewNormal);
            if (smoothness > EPSILON) {

                #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
                    vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
                    vec3 viewPosPrev = (gbufferPreviousModelView * vec4(localPos - previousCameraPosition, 1.0)).xyz;

                    vec3 localReflectDir = mat3(gbufferModelViewInverse) * reflectDir;
                    vec3 reflectDirPrev = mat3(gbufferPreviousModelView) * localReflectDir;

                    // TODO: move to vertex shader?
                    int maxHdrPrevLod = textureQueryLevels(BUFFER_HDR_PREVIOUS);
                    int lod = int(rough * max(maxHdrPrevLod - EPSILON, 0.0));

                    vec4 roughReflectColor = GetReflectColor(BUFFER_DEPTH_PREV, viewPosPrev, reflectDirPrev, lod);

                    reflectColor = (roughReflectColor.rgb / exposure) * roughReflectColor.a;
                    //reflectColor = clamp(reflectColor, vec3(0.0), vec3(65000.0));

                    #ifdef SKY_ENABLED
                        if (roughReflectColor.a + EPSILON < 1.0) {
                            vec3 skyReflectColor = GetSkyReflectionColor(lightData, reflectDir) * skyLight3;
                            reflectColor += skyReflectColor * (1.0 - roughReflectColor.a);
                        }
                    #endif

                #elif REFLECTION_MODE == REFLECTION_MODE_SKY && defined SKY_ENABLED
                    reflectColor = GetSkyReflectionColor(lightData, reflectDir) * skyLight3;
                #endif
            }
        #endif

        #if defined SKY_ENABLED && defined RSM_ENABLED && defined RENDER_DEFERRED
            vec2 tex = screenUV;

            #ifdef RSM_UPSCALE
                vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos, 1.0))).xyz;
                vec3 shadowViewNormal = mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * viewNormal);

                vec3 rsmColor = GetUpscaledRSM(lightData, shadowViewPos, shadowViewNormal, -viewPos.z, tex);
            #else
                vec3 rsmColor = textureLod(BUFFER_RSM_COLOR, tex, 0).rgb;
            #endif
        #endif

        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
            vec3 blockLightAmbient = pow2(blockLight)*blockLightColor;
        #else
            vec3 blockLightAmbient = pow5(blockLight)*blockLightColor;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            vec3 specularTint = GetHCM_Tint(material.albedo.rgb, material.hcm);
        #else
            vec3 specularTint = mix(vec3(1.0), material.albedo.rgb, material.f0);
        #endif

        vec4 final = vec4(albedo, material.albedo.a);
        vec3 ambient = vec3(MinWorldLux + blockLightAmbient);
        vec3 diffuse = vec3(0.0);
        vec3 specular = vec3(0.0);
        float occlusion = lightData.occlusion * material.occlusion;

        // ERROR: The occlusion multiply above is what's causing the vanilla water texture to be visible!
        #if defined SSAO_ENABLED && !defined RENDER_WATER && !defined RENDER_HAND_WATER
           occlusion *= textureLod(BUFFER_AO, texcoord, 0).r;
        #endif

        vec3 iblF = vec3(0.0);
        vec3 iblSpec = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            if (any(greaterThan(reflectColor, vec3(EPSILON)))) {
                vec2 envBRDF = textureLod(BUFFER_BRDF_LUT, vec2(NoVm, rough), 0).rg;

                #ifndef IS_OPTIFINE
                    envBRDF = RGBToLinear(vec3(envBRDF, 0.0)).rg;
                #endif

                iblF = GetFresnel(material.albedo.rgb, f0, material.hcm, NoVm, rough);
                iblSpec = iblF * envBRDF.r + envBRDF.g;
                iblSpec *= (1.0 - rough) * reflectColor * occlusion;

                float iblFmax = max(max(iblF.x, iblF.y), iblF.z);
                final.a += iblFmax * max(1.0 - final.a, 0.0);
            }
        #endif

        float sunLux = 0.0;
        #ifdef SKY_ENABLED
            float ambientBrightness = mix(0.8 * skyLight2, 0.95 * skyLight, rainStrength);// * SHADOW_BRIGHTNESS;
            vec3 skyAmbient = GetSkyAmbientLight(lightData, viewNormal);

            sunLux = GetSunLux();
            vec3 sunColor = lightData.sunTransmittance * sunLux;

            vec3 skyLightColorFinal = (sunColor + moonColor) * shadowColor;

            ambient += skyAmbient * ambientBrightness;
            //return vec4(ambient, 1.0);

            //#ifdef SSS_ENABLED
            //    ambient += skyAmbientSSS * ambientBrightness * material.scattering;
            //#endif

            vec3 sunF = GetFresnel(material.albedo.rgb, f0, material.hcm, LoHm, roughL);

            vec3 sunDiffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL) * max(1.0 - sunF, 0.0);
            //sunDiffuse = GetDiffuseBSDF(sunDiffuse, albedo, material.scattering, NoVm, diffuseNoL, LoHm, roughL);
            sunDiffuse *= skyLightColorFinal * shadowFinal;// * skyLight2;

            #ifdef SSS_ENABLED
                if (material.scattering > 0.0 && shadowSSS > 0.0) {
                    // Transmission
                    vec3 sssDiffuseLight = material.albedo.rgb;
                    if (dot(sssDiffuseLight, sssDiffuseLight) > EPSILON)
                        sssDiffuseLight = normalize(sssDiffuseLight);
                    
                    sssDiffuseLight *= pow2(shadowSSS) * skyLightColorFinal;// * skyLight;

                    float VoL = dot(-viewDir, viewLightDir);
                    sssDiffuseLight *= ComputeVolumetricScattering(VoL, 0.4);
                    //sssDiffuseLight *= BiLambertianPlatePhaseFunction(0.9, VoL);

                    float extDistF = (1.0 - 0.9*material.scattering) * sssDist;
                    sssDiffuseLight *= exp(-extDistF * (1.0 - material.albedo.rgb));
                    //sssDiffuseLight *= exp(-extDistF);

                    sunDiffuse += sssDiffuseLight * (0.1 * SSS_STRENGTH);// * max(NoL, 0.0);
                }
            #endif

            diffuse += sunDiffuse * material.albedo.a;

            if (NoLm > EPSILON) {
                float NoHm = max(dot(viewNormal, halfDir), 0.0);

                vec3 sunSpec = GetSpecularBRDF(sunF, NoVm, NoLm, NoHm, roughL) * skyLightColorFinal * skyLight2 * shadowFinal;
                
                specular += sunSpec;// * material.albedo.a;

                final.a = min(final.a + luminance(sunSpec) * exposure, 1.0);
            }
        #endif

        #if defined HANDLIGHT_ENABLED && !defined RENDER_HAND && !defined RENDER_HAND_WATER
            if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
                vec3 handDiffuse, handSpecular;
                ApplyHandLighting(handDiffuse, handSpecular, material.albedo.rgb, f0, material.hcm, material.scattering, viewNormal, viewPos.xyz, viewDir, NoVm, roughL);

                diffuse += handDiffuse;
                specular += handSpecular;

                final.a = min(final.a + luminance(handSpecular) * exposure, 1.0);
            }
        #endif

        #if defined RENDER_WATER && !defined WORLD_NETHER && !defined WORLD_END
            if (materialId == 1) {
                const float ScatteringCoeff = 0.11;

                //vec3 extinction = vec3(0.54, 0.91, 0.93);
                //vec3 extinctionInv = 1.0 - WaterAbsorbtionExtinction;
                vec3 extinctionInv = 1.0 - WATER_COLOR.rgb;
                //vec3 extinction = 1.0 - material.albedo.rgb;

                #if WATER_REFRACTION != WATER_REFRACTION_NONE
                    float waterRefractEta = isEyeInWater == 1
                        ? IOR_WATER / IOR_AIR
                        : IOR_AIR / IOR_WATER;
                    
                    float refractDist = max(lightData.opaqueScreenDepth - lightData.transparentScreenDepth, 0.0);

                    vec2 waterSolidDepthFinal;
                    vec3 refractColor = vec3(0.0);
                    vec3 refractDir = refract(vec3(0.0, 0.0, -1.0), viewNormal, waterRefractEta); // TODO: subtract geoViewNormal from texViewNormal
                    if (dot(refractDir, refractDir) > EPSILON) {
                        vec2 refractOffset = refractDir.xy;

                        // scale down contact point to avoid tearing
                        vec2 minMax = vec2(0.01 * REFRACTION_STRENGTH);
                        refractOffset = clamp(0.1 * refractOffset * refractDist, -minMax, minMax);

                        // scale down with distance
                        //float distF = 1.0 - saturate((viewDist - near) / (far - near));
                        //refractOffset *= pow2(distF);
                        
                        vec2 refractUV = screenUV + refractOffset;

                        waterSolidDepthFinal.y = lightData.opaqueScreenDepth;
                        waterSolidDepthFinal.x = lightData.transparentScreenDepth;

                        #if WATER_REFRACTION == WATER_REFRACTION_FANCY
                            // update water depth
                            waterSolidDepthFinal = GetWaterSolidDepth(refractUV);

                            vec2 startUV = refractUV;
                            vec2 d = screenUV - startUV;
                            vec2 dp = d * viewSize;

                            float stepCount = abs(dp.x) > abs(dp.y) ? abs(dp.x) : abs(dp.y);

                            if (stepCount > 1.0) {
                                vec2 step = d / stepCount;

                                float solidViewDepth = 0.0;
                                for (int i = 0; i <= stepCount && solidViewDepth < waterSolidDepthFinal.x; i++) {
                                    refractUV = startUV + i * step;
                                    solidViewDepth = textureLod(depthtex1, refractUV, 0).r;
                                    solidViewDepth = linearizeDepthFast(solidViewDepth, near, far);
                                }

                                waterSolidDepthFinal.y = solidViewDepth;//linearizeDepthFast(solidViewDepth, near, far);
                            }
                        #else
                            if (waterSolidDepthFinal.y < waterSolidDepthFinal.x) {
                                // refracted vector returned an invalid hit
                                //waterSolidDepthFinal.x = lightData.transparentScreenDepth;
                                //waterSolidDepthFinal.y = lightData.opaqueScreenDepth;
                                refractUV = screenUV;
                            }
                        #endif

                        #ifdef MC_GL_VENDOR_NVIDIA
                            ivec2 iuv = ivec2(refractUV * viewSize);
                            refractColor = texelFetch(BUFFER_HDR, iuv, 0).rgb / exposure;
                        #else
                            refractColor = textureLod(BUFFER_REFRACT, refractUV, 0).rgb / exposure;
                        #endif
                    }
                    else {
                        // TIR
                        waterSolidDepthFinal.x = 65000;
                        waterSolidDepthFinal.y = 65000;
                    }

                    float waterDepthFinal = isEyeInWater == 1 ? waterSolidDepthFinal.x
                        : max(waterSolidDepthFinal.y - waterSolidDepthFinal.x, 0.0);

                    vec3 scatterColor = WATER_SCATTER_COLOR * lightData.sunTransmittanceEye;// * skyLight2;// * shadowFinal;
                    //float lightDepth = lightData.waterShadowDepth + waterDepthFinal;

                    vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterDepthFinal * extinctionInv);
                    float inverseScatterAmount = saturate(1.0 - exp(-WATER_SCATTER_RATE * waterDepthFinal));

                    diffuse = refractColor * mix(vec3(1.0), scatterColor, inverseScatterAmount) * absorption;
                    ambient = vec3(0.0);
                    final.a = 1.0;
                #else
                    //float waterSurfaceDepth = textureLod(shadowtex0);
                    //float solidSurfaceDepth = textureLod(shadowtex1);

                    float waterViewDepth = isEyeInWater == 1 ? lightData.transparentScreenDepth
                        : max(lightData.opaqueScreenDepth - lightData.transparentScreenDepth, 0.0);

                    float waterLightDist = waterViewDepth + lightData.waterShadowDepth;

                    //float verticalDepth = waterViewDepth * max(dot(viewLightDir, viewUpDir), 0.0);
                    vec3 absorption = exp(-waterLightDist * extinctionInv);
                    float scatterAmount = exp(0.01 * -waterLightDist);

                    vec3 scatterColor = material.albedo.rgb * skyLightColorFinal * skyLight2;// * shadowFinal;

                    //diffuse = (diffuse + scatterColor * scatterAmount) * absorption;
                    //diffuse = scatterColor * scatterAmount * absorption;
                    diffuse *= absorption;

                    ambient = vec3(0.0);
                    //diffuse = vec3(0.0);
                    //specular = vec3(0.0);
                    
                    //float alphaF = exp(-(waterViewDepth + lightData.waterShadowDepth));
                    float alphaF = exp(-waterViewDepth);
                    final.a = min(final.a + (1.0 - saturate(alphaF)), 1.0);// * (1.0 - material.albedo.a);// * max(1.0 - final.a, 0.0);
                    //final.a = 1.0;
                #endif
            }
        #endif

        #if defined SKY_ENABLED && defined RSM_ENABLED && defined RENDER_DEFERRED
            ambient += rsmColor * skyLightColorFinal;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            if (material.hcm >= 0) {
                //if (material.hcm < 8) specular *= material.albedo.rgb;

                diffuse *= roughL * METAL_AMBIENT;
                ambient *= roughL * METAL_AMBIENT;
            }
        #else
            float metalDarkF = 1.0 - material.f0 * (1.0 - METAL_AMBIENT);
            diffuse *= metalDarkF;
            ambient *= metalDarkF;
        #endif

        vec3 emissive = material.albedo.rgb * pow(material.emission, 2.2) * EmissionLumens;

        //occlusion = 1.0 - SHADOW_BRIGHTNESS * (1.0 - occlusion);
        //occlusion = SHADOW_BRIGHTNESS + occlusion * (1.0 - SHADOW_BRIGHTNESS);
        occlusion *= SHADOW_BRIGHTNESS;

        final.rgb = final.rgb * (ambient * occlusion)
            + diffuse + emissive
            + (specular + iblSpec) * specularTint;

        final.rgb *= exp(-ATMOS_EXTINCTION * viewDist);

        //final.rgb = (reflectDir * 0.5 + 0.5) * 1000.0;

        #if defined SKY_ENABLED && defined RENDER_DEFERRED
            if (isEyeInWater == 1) {
                vec3 extinctionInv = 1.0 - WATER_COLOR.rgb;

                //vec3 absorption = exp(-(lightData.opaqueScreenDepth + lightData.waterShadowDepth) * extinctionInv);// * shadowFinal;

                //skyLightColorFinal *= absorption;

                //vec3 ambientAbsorption = exp(-lightData.opaqueScreenDepth * extinctionInv);
                //skyAmbient *= ambientAbsorption * skyLight3;

                float waterDepthFinal = lightData.opaqueScreenDepth;

                vec3 scatterColor = WATER_SCATTER_COLOR * lightData.sunTransmittanceEye;// * skyLight2;// * shadowFinal;
                //float lightDepth = lightData.waterShadowDepth + waterDepthFinal;

                vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterDepthFinal * extinctionInv);
                float inverseScatterAmount = saturate(1.0 - exp(-WATER_SCATTER_RATE * waterDepthFinal));

                final.rgb *= mix(vec3(1.0), scatterColor, inverseScatterAmount) * absorption;
            }
        #endif

        if (isEyeInWater == 1) {
            float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);

            #ifdef SKY_ENABLED
                // TODO: Get this outa here (vertex shader)
                //vec2 skyLightLevels = GetSkyLightLevels();
                vec3 skyLightLuxColor = GetSkyLightLuxColor(lightData.skyLightLevels);
            #else
                vec3 skyLightLuxColor = vec3(100.0);
            #endif

            // apply water fog
            float waterFogEnd = min(40.0, fogEnd);
            float waterFogF = GetFogFactor(viewDist, near, waterFogEnd, 0.8);
            vec3 waterFogColor = WATER_COLOR.rgb * 0.02 * skyLightLuxColor * (0.02 + 0.98*eyeLight);
            //final.rgb = mix(final.rgb, waterFogColor, waterFogF);
        }
        else {
            //vec3 sunTransmittanceLux = lightData.sunTransmittance * sunLux;

            #ifdef RENDER_DEFERRED
                ApplyFog(final.rgb, viewPos, lightData);
            #elif defined RENDER_GBUFFER
                #if defined RENDER_WATER || defined RENDER_HAND_WATER
                    ApplyFog(final, viewPos, lightData, EPSILON);
                #else
                    ApplyFog(final, viewPos, lightData, alphaTestRef);
                #endif
            #endif
        }

        #if defined SKY_ENABLED && defined VL_ENABLED
            mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
            vec3 shadowViewStart = (matViewToShadowView * vec4(vec3(0.0, 0.0, -near), 1.0)).xyz;
            vec3 shadowViewEnd = (matViewToShadowView * vec4(viewPos, 1.0)).xyz;

            float vlScatter = GetScatteringFactor(lightData.skyLightLevels.x);
            //vec3 vlColor = sunColor + moonColor;
            vec3 vlColor = vec3(0.0);

            vec3 sunDir = normalize(sunPosition);
            float sun_VoL = dot(-viewDir, sunDir);
            float sunScattering = ComputeVolumetricScattering(sun_VoL, vlScatter);
            vlColor += max(sunScattering, 0.0) * lightData.sunTransmittanceEye * GetSunLux();// * sunColor;

            vec3 moonDir = normalize(moonPosition);
            float moon_VoL = dot(-viewDir, moonDir);
            float moonScattering = ComputeVolumetricScattering(moon_VoL, vlScatter);
            vlColor += max(moonScattering, 0.0) * moonColor;

            if (isEyeInWater == 1) vlColor *= WATER_SCATTER_COLOR.rgb;

            #ifdef SHADOW_COLOR
                vlColor *= GetVolumetricLightingColor(lightData, shadowViewStart, shadowViewEnd);
            #else
                vlColor *= GetVolumetricLighting(lightData, shadowViewStart, shadowViewEnd);
            #endif
            
            final.rgb += vlColor * (0.01 * VL_STRENGTH);
        #endif

        return final;
    }
#endif
