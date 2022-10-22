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
        float NoV = dot(viewNormal, viewDir);
        float NoVm = max(NoV, 0.0);
        vec3 viewUpDir = normalize(upPosition);

        float blockLight = saturate((lightData.blockLight - (1.0/16.0 + EPSILON)) / (15.0/16.0));
        float skyLight = saturate((lightData.skyLight - (1.0/16.0 + EPSILON)) / (15.0/16.0));

        vec3 albedo = material.albedo.rgb;
        float smoothness = material.smoothness;
        float f0 = material.f0;

        #if defined SKY_ENABLED
            float wetnessFinal = biomeWetness * GetDirectionalWetness(viewNormal, skyLight);

            #ifdef RENDER_WATER
                if (materialId != 100 && materialId != 101) {
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
        float shadowSSS = 0.0;

        #ifdef SKY_ENABLED
            float sunLightLevel = GetSunLightLevel(lightData.skyLightLevels.x);
            float sssDist = 0.0;

            shadow *= step(EPSILON, lightData.geoNoL);
            shadow *= step(EPSILON, NoL);

            float contactShadow = 1.0;
            float contactLightDist = 0.0;
            #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
                #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                    const float minContactShadowDist = 0.75 * shadowDistance;
                #else
                    const float minContactShadowDist = 0.0;
                #endif

                //if (shadow <= EPSILON) contactShadow = 0.0;
                if (viewDist >= minContactShadowDist) {
                    //vec3 lightDir = viewLightDir;// * 60.0 * saturate(viewDist / far);
                    float contactMinDist = 0.0;
                    contactShadow = GetContactShadow(depthtex1, viewPos, viewLightDir, contactMinDist, contactLightDist);
                }
            #endif

            #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                if (shadow > EPSILON)
                    shadow *= GetShadowing(lightData);

                #ifdef SHADOW_COLOR
                    shadowColor = GetShadowColor(lightData);
                    shadowColor = RGBToLinear(shadowColor);
                #endif

                #ifdef SSS_ENABLED
                    if (material.scattering > EPSILON) {
                        shadowSSS = GetShadowSSS(lightData, material.scattering, sssDist);
                    }
                #endif
            #else
                shadow = pow2(skyLight) * lightData.occlusion;
                shadowSSS = pow2(skyLight) * material.scattering;
            #endif

            #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
                #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                    float contactShadowMix = saturate(0.2 * (viewDist - minContactShadowDist));
                    contactShadow = mix(1.0, contactShadow, contactShadowMix);
                #endif

                shadow = min(shadow, contactShadow);

                shadowSSS *= mix(1.0, contactShadow, saturate(contactLightDist / (SSS_MAXDIST * material.scattering)));
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
            #ifdef RSM_UPSCALE
                vec2 rsmViewSize = viewSize / exp2(RSM_SCALE);
                vec3 rsmColor = BilateralGaussianDepthBlurRGB_5x(BUFFER_RSM_COLOR, rsmViewSize, BUFFER_RSM_DEPTH, rsmViewSize, lightData.opaqueScreenDepth, 0.9);
            #else
                vec2 tex = screenUV;
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

        #if defined SSAO_ENABLED && !defined RENDER_WATER && !defined RENDER_HAND_WATER
            occlusion = BilateralGaussianDepthBlur_9x(BUFFER_AO, 0.5 * viewSize, depthtex0, viewSize, lightData.opaqueScreenDepth, 0.9);
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
                iblSpec *= (1.0 - roughL) * reflectColor * occlusion;

                float iblFmax = max(max(iblF.x, iblF.y), iblF.z);
                final.a += iblFmax * max(1.0 - final.a, 0.0);
            }
        #endif

        #ifdef SKY_ENABLED
            float ambientBrightness = mix(0.8 * skyLight2, 0.95 * skyLight, rainStrength);// * SHADOW_BRIGHTNESS;
            ambient += GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;

            vec3 sunColor = lightData.sunTransmittance * GetSunLux();
            vec3 skyLightColorFinal = (sunColor + moonColor) * shadowColor;

            vec3 sunF = GetFresnel(material.albedo.rgb, f0, material.hcm, LoHm, roughL);

            vec3 sunDiffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL);// * max(1.0 - sunF, 0.0);
            //sunDiffuse = GetDiffuseBSDF(sunDiffuse, albedo, material.scattering, NoVm, diffuseNoL, LoHm, roughL);
            sunDiffuse *= skyLightColorFinal * shadowFinal;// * skyLight2;

            #ifdef SSS_ENABLED
                if (material.scattering > 0.0 && shadowSSS > 0.0) {
                    // Transmission
                    vec3 sssAlbedo = material.albedo.rgb;
                    if (dot(sssAlbedo, sssAlbedo) > EPSILON)
                        sssAlbedo = normalize(sssAlbedo);
                    
                    //sssAlbedo *= sssAlbedo;
                    vec3 sssDiffuseLight = sssAlbedo * shadowSSS * skyLightColorFinal * skyLight2;

                    float extDistF = 0.1 + 4.0*(sssDist / SSS_MAXDIST);
                    sssDiffuseLight *= exp(-extDistF * material.scattering * (1.0 - material.albedo.rgb));

                    float VoL = dot(-viewDir, viewLightDir);
                    //sssDiffuseLight *= BiLambertianPlatePhaseFunction(-NoV, 0.6);
                    float scatter = mix(0.0, 0.8, material.scattering);
                    float inScatter = material.scattering * ComputeVolumetricScattering(NoL, -0.5);
                    float outScatter = 0.7 * ComputeVolumetricScattering(VoL, scatter);

                    //sssDiffuseLight *= 2.0 * saturate(inScatter) * saturate(outScatter);
                    //sssDiffuseLight *= exp(-extDistF);

                    sunDiffuse += sssDiffuseLight * (saturate(inScatter) + saturate(outScatter)) * (0.1 * SSS_STRENGTH);// * max(NoL, 0.0);
                }
            #endif

            diffuse += max(1.0 - sunF, 0.0) * sunDiffuse;// * material.albedo.a;

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
            if (materialId == 100 || materialId == 101) {
                const float ScatteringCoeff = 0.11;

                vec3 extinctionInv = 1.0 - WATER_COLOR.rgb;

                #if WATER_REFRACTION != WATER_REFRACTION_NONE
                    float waterRefractEta = isEyeInWater == 1
                        ? IOR_WATER / IOR_AIR
                        : IOR_AIR / IOR_WATER;
                    
                    float refractDist = max(lightData.opaqueScreenDepth - lightData.transparentScreenDepth, 0.0);

                    vec2 waterSolidDepthFinal;
                    vec3 refractColor = vec3(0.0);
                    vec3 refractDir = refract(viewDir, viewNormal, waterRefractEta); // TODO: subtract geoViewNormal from texViewNormal
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
                                refractUV = screenUV;
                            }
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
                    final.a = 1.0;

                    float eyeLight = saturate(eyeBrightness.y / 240.0);

                    #ifdef SKY_ENABLED
                        // TODO: Get this outa here (vertex shader)
                        vec3 skyLightLuxColor = lightData.sunTransmittanceEye * GetSunLux();// GetSkyLightLuxColor(lightData.skyLightLevels);
                    #else
                        vec3 skyLightLuxColor = vec3(100.0);
                    #endif

                    ApplyWaterFog(diffuse, lightData, skyLightLuxColor * pow(eyeLight, 3.0));
                #else
                    float waterViewDepth = isEyeInWater == 1 ? lightData.transparentScreenDepth
                        : max(lightData.opaqueScreenDepth - lightData.transparentScreenDepth, 0.0);

                    float waterLightDist = waterViewDepth + lightData.waterShadowDepth;

                    //float verticalDepth = waterViewDepth * max(dot(viewLightDir, viewUpDir), 0.0);
                    vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterViewDepth * extinctionInv);
                    float scatterAmount = exp(-WATER_SCATTER_RATE * waterViewDepth);

                    vec3 scatterColor = WATER_SCATTER_COLOR * lightData.sunTransmittanceEye;// * skyLight2;// * shadowFinal;

                    diffuse *= mix(scatterColor, vec3(1.0), scatterAmount) * absorption;
                    
                    //float alphaF = exp(-(waterViewDepth + lightData.waterShadowDepth));
                    float alphaF = exp(-0.2 * WATER_ABSROPTION_RATE * waterViewDepth);
                    final.a = min(final.a + (1.0 - saturate(alphaF)), 1.0);// * (1.0 - material.albedo.a);// * max(1.0 - final.a, 0.0);
                #endif

                ambient = vec3(0.0);
            }
        #endif

        #if defined SKY_ENABLED && defined RSM_ENABLED && defined RENDER_DEFERRED
            ambient += rsmColor * skyLightColorFinal;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            if (material.hcm >= 0) {
                //if (material.hcm < 8) specular *= material.albedo.rgb;

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

        occlusion *= SHADOW_BRIGHTNESS;

        final.rgb = final.rgb * (ambient * occlusion)
            + diffuse + emissive
            + (specular + iblSpec) * specularTint;

        final.rgb *= exp(-ATMOS_EXTINCTION * viewDist);

        bool isUnderwater = lightData.shadowPos.z > lightData.transparentShadowDepth && abs(lightData.opaqueShadowDepth - lightData.transparentShadowDepth) > 0.001;

        #if defined SKY_ENABLED && defined RENDER_DEFERRED
            if (isEyeInWater == 1 && isUnderwater) {
                vec3 extinctionInv = 1.0 - WATER_COLOR.rgb;

                float waterDepthFinal = lightData.opaqueScreenDepth;

                vec3 scatterColor = WATER_SCATTER_COLOR * lightData.sunTransmittanceEye;// * skyLight2;// * shadowFinal;
                //float lightDepth = lightData.waterShadowDepth + waterDepthFinal;

                vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterDepthFinal * extinctionInv);
                float inverseScatterAmount = 1.0 - saturate(exp(-WATER_SCATTER_RATE * waterDepthFinal));

                final.rgb *= mix(vec3(1.0), scatterColor, inverseScatterAmount) * absorption;
            }
        #endif

        float fogFactor;
        if (isEyeInWater == 1 && isUnderwater) {// || lightData.shadowPos.z > lightData.opaqueShadowDepth)) {
            float eyeLight = saturate(eyeBrightness.y / 240.0);

            #ifdef SKY_ENABLED
                // TODO: Get this outa here (vertex shader)
                vec3 skyLightLuxColor = lightData.sunTransmittanceEye * GetSunLux();// GetSkyLightLuxColor(lightData.skyLightLevels);
            #else
                vec3 skyLightLuxColor = vec3(100.0);
            #endif

            // // apply water fog
            // float waterFogEnd = min(32.0, fogEnd);
            // fogFactor = GetFogFactor(min(lightData.opaqueScreenDepth, lightData.transparentScreenDepth), 0.0, waterFogEnd, 1.0);
            // vec3 waterFogColor = 0.1*WATER_SCATTER_COLOR * skyLightLuxColor * pow(eyeLight, 3.0);
            // final.rgb = mix(final.rgb, waterFogColor, fogFactor);
            fogFactor = ApplyWaterFog(final.rgb, lightData, skyLightLuxColor * pow(eyeLight, 3.0));
        }
        else {
            #ifdef RENDER_WATER
                if (materialId != 100 || isEyeInWater != 1) {
            #endif

            #ifdef RENDER_DEFERRED
                fogFactor = ApplyFog(final.rgb, viewPos, lightData);
            #elif defined RENDER_GBUFFER
                #if defined RENDER_WATER || defined RENDER_HAND_WATER
                    fogFactor = ApplyFog(final, viewPos, lightData, EPSILON);
                #else
                    fogFactor = ApplyFog(final, viewPos, lightData, alphaTestRef);
                #endif
            #endif

            #ifdef SKY_ENABLED
                vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux(); // * sunColor
                vec3 vlColor = GetVanillaSkyScattering(-viewDir, skyLightLevels, sunColorFinal, moonColor);

                #ifdef VL_ENABLED
                    mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
                    vec3 shadowViewStart = (matViewToShadowView * vec4(vec3(0.0, 0.0, -near), 1.0)).xyz;
                    vec3 shadowViewEnd = (matViewToShadowView * vec4(viewPos, 1.0)).xyz;

                    #ifdef SHADOW_COLOR
                        vlColor *= GetVolumetricLightingColor(lightData, shadowViewStart, shadowViewEnd);
                    #else
                        vlColor *= GetVolumetricLighting(lightData, shadowViewStart, shadowViewEnd);
                    #endif
                #else
                    vlColor *= fogFactor;
                #endif
                
                final.rgb += vlColor;
            #endif

            #ifdef RENDER_WATER
                }
            #endif
        }

        return final;
    }
#endif
