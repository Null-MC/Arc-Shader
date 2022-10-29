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
    // #ifdef RENDER_WATER
    //     float GetWaterDepth(const in vec2 screenUV) {
    //         float waterViewDepthLinear = linearizeDepthFast(gl_FragCoord.z, near, far);
    //         if (isEyeInWater == 1) return waterViewDepthLinear;

    //         float solidViewDepth = textureLod(depthtex1, screenUV, 0).r;
    //         float solidViewDepthLinear = linearizeDepthFast(solidViewDepth, near, far);
    //         return max(solidViewDepthLinear - waterViewDepthLinear, 0.0);
    //     }

    //     // returns: x=transparent-depth, y=opaque-depth
    //     vec2 GetWaterSolidDepth(const in vec2 screenUV) {
    //         float solidViewDepth = textureLod(depthtex1, screenUV, 0).r;
    //         float solidViewDepthLinear = linearizeDepthFast(solidViewDepth, near, far);
    //         float waterViewDepthLinear = linearizeDepthFast(gl_FragCoord.z, near, far);

    //         return vec2(waterViewDepthLinear, solidViewDepthLinear);
    //     }
    // #endif

    #ifdef SKY_ENABLED
        vec3 GetSkyReflectionColor(const in LightData lightData, const in vec3 viewDir, const in vec3 reflectDir) {
            #ifdef RENDER_WATER
                if (materialId == 100 && isEyeInWater == 1)
                    return GetWaterFogColor(viewDir, lightData.sunTransmittance, lightData.sunTransmittanceEye);
            #endif

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

            // darken lower horizon
            vec3 downDir = normalize(-upPosition);
            float RoDm = max(dot(reflectDir, downDir), 0.0);
            //float reflectF = 1.0 - RoDm;

            #ifdef RENDER_WATER
                if (materialId == 100) {
                    vec3 waterFogColor = GetWaterFogColor(viewDir, lightData.sunTransmittance, lightData.sunTransmittanceEye);
                    return mix(skyColor, waterFogColor, RoDm);
                }
            #endif

            return skyColor * (1.0 - RoDm);
        }
    #endif

    vec4 PbrLighting2(const in PbrMaterial material, const in LightData lightData, const in vec3 viewPos) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = -normalize(viewPos);
        float viewDist = length(viewPos);

        #ifdef RENDER_DEFERRED
            vec2 screenUV = texcoord;
        #else
            vec2 screenUV = gl_FragCoord.xy / viewSize;
        #endif

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
            //float sunLightLevel = GetSunLightLevel(lightData.skyLightLevels.x);
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
                float contactShadowMix = saturate(0.2 * (viewDist - minContactShadowDist));

                #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                    contactShadow = mix(1.0, contactShadow, contactShadowMix);
                #endif

                shadow = min(shadow, contactShadow);
                sssDist = max(sssDist, contactLightDist);

                float maxDist = SSS_MAXDIST * material.scattering;
                float contactSSS = 0.7 * pow2(material.scattering) * max(1.0 - contactLightDist / maxDist, 0.0);
                shadowSSS = mix(shadowSSS, contactSSS, contactShadowMix);
                //shadowSSS *= mix(1.0, contactShadow, saturate(contactLightDist / (SSS_MAXDIST * material.scattering)));
            #endif
        #endif

        float shadowFinal = shadow;

        #ifdef LIGHTLEAK_FIX
            // Make areas without skylight fully shadowed (light leak fix)
            float lightLeakFix = saturate(skyLight * 15.0);
            shadowFinal *= lightLeakFix;
            shadowSSS *= lightLeakFix;
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            // Increase skylight when in direct sunlight
            if (isEyeInWater != 1)
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
                            vec3 skyReflectColor = GetSkyReflectionColor(lightData, viewDir, reflectDir) * skyLight3;
                            reflectColor += skyReflectColor * (1.0 - roughReflectColor.a);
                        }
                    #endif
                #elif REFLECTION_MODE == REFLECTION_MODE_SKY && defined SKY_ENABLED
                    reflectColor = GetSkyReflectionColor(lightData, viewDir, reflectDir) * skyLight3;
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
            vec3 blockLightDiffuse = pow2(blockLight)*blockLightColor;
        #else
            vec3 blockLightDiffuse = pow5(blockLight)*blockLightColor;
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
        float occlusion = lightData.occlusion * material.occlusion;

        #if defined SSAO_ENABLED && !defined RENDER_WATER && !defined RENDER_HAND_WATER
            occlusion = BilateralGaussianDepthBlur_9x(BUFFER_AO, 0.5 * viewSize, depthtex0, viewSize, lightData.opaqueScreenDepthLinear, 0.9);
        #endif

        vec3 iblF = vec3(0.0);
        vec3 iblSpec = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            iblF = GetFresnel(material.albedo.rgb, f0, material.hcm, NoVm, roughL);

            if (any(greaterThan(reflectColor, vec3(EPSILON)))) {
                vec2 envBRDF = textureLod(BUFFER_BRDF_LUT, vec2(NoVm, rough), 0).rg;

                #ifndef IS_OPTIFINE
                    envBRDF = RGBToLinear(vec3(envBRDF, 0.0)).rg;
                #endif

                iblSpec = iblF * envBRDF.r + envBRDF.g;
                iblSpec *= (1.0 - roughL) * reflectColor * occlusion;

                float iblFmax = max(max(iblF.x, iblF.y), iblF.z);
                //final.a += iblFmax * max(1.0 - final.a, 0.0);
                final.a = min(final.a + iblFmax * exposure * final.a, 1.0);
            }
        #endif

        #ifdef SKY_ENABLED
            float ambientBrightness = mix(0.8 * skyLight2, 0.95 * skyLight, rainStrength);// * SHADOW_BRIGHTNESS;
            vec3 skyAmbient = GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;

            vec3 sunColor = lightData.sunTransmittance * GetSunLux();
            vec3 skyLightColorFinal = (sunColor + moonColor) * shadowColor;

            bool applyWaterAbsorption = isEyeInWater == 1;

            #ifdef RENDER_WATER
                if (materialId == 100 || materialId == 101) applyWaterAbsorption = false;
            #endif

            if (applyWaterAbsorption) {
                float waterLightDist = max(lightData.opaqueScreenDepthLinear + lightData.waterShadowDepth, 0.0);

                const vec3 extinctionInv = 1.0 - WATER_ABSORB_COLOR;
                vec3 absorption = exp(-extinctionInv * waterLightDist);
                //if (lightData.waterShadowDepth < EPSILON) absorption = vec3(0.0);

                skyAmbient *= absorption;
                //skyAmbient *= skyLight3;

                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    if (lightData.geoNoL < 0.0 || lightData.opaqueShadowDepth < lightData.shadowPos[lightData.opaqueShadowCascade].z - lightData.shadowBias[lightData.opaqueShadowCascade]) absorption = vec3(0.0);
                #else
                    if (lightData.geoNoL < 0.0 || lightData.opaqueShadowDepth < lightData.shadowPos.z - lightData.shadowBias) absorption = vec3(0.0);
                #endif


                skyLightColorFinal *= absorption;// * skyLight3;
                //reflectColor *= absorption;
                iblSpec *= absorption;
            }

            ambient += skyAmbient;

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

                    float extDistF = (sssDist / SSS_MAXDIST) * material.scattering;
                    sssDiffuseLight *= exp(-4.0 * extDistF * (1.2 - material.albedo.rgb));

                    float VoL = dot(-viewDir, viewLightDir);
                    //sssDiffuseLight *= BiLambertianPlatePhaseFunction(-NoV, 0.6);
                    float scatter = mix(0.2, 0.9, material.scattering);
                    float inScatter = material.scattering * ComputeVolumetricScattering(NoL, -0.5);
                    float outScatter = 0.5 * ComputeVolumetricScattering(VoL, scatter);

                    //sssDiffuseLight *= 2.0 * saturate(inScatter) * saturate(outScatter);
                    //sssDiffuseLight *= exp(-extDistF);

                    sunDiffuse += sssDiffuseLight * (saturate(inScatter) + saturate(outScatter)) * (0.1 * SSS_STRENGTH);// * max(NoL, 0.0);
                }
            #endif

            diffuse += sunDiffuse * max(1.0 - sunF, 0.0);// * material.albedo.a;

            if (NoLm > EPSILON) {
                float NoHm = max(dot(viewNormal, halfDir), 0.0);

                vec3 sunSpec = GetSpecularBRDF(sunF, NoVm, NoLm, NoHm, roughL) * skyLightColorFinal * skyLight2 * shadowFinal * final.a;
                
                specular += sunSpec;// * material.albedo.a;

                final.a = min(final.a + luminance(sunSpec) * exposure, 1.0);
            }
        #endif

        #if defined RENDER_WATER && !defined WORLD_NETHER && !defined WORLD_END
            if (materialId == 100 || materialId == 101) {
                //return vec4(material.normal * 1000.0, 1.0);

                const float ScatteringCoeff = 0.11;

                const vec3 extinctionInv = 1.0 - WATER_ABSORB_COLOR;

                #if WATER_REFRACTION != WATER_REFRACTION_NONE
                    float waterRefractEta = isEyeInWater == 1
                        ? IOR_WATER / IOR_AIR
                        : IOR_AIR / IOR_WATER;
                    
                    //vec3 waterNormal = viewNormal;
                    //if (isEyeInWater == 1) waterNormal = -waterNormal;

                    vec3 refractDir = refract(-viewDir, viewNormal, waterRefractEta);

                    float refractOpaqueScreenDepth = lightData.opaqueScreenDepth;
                    float refractOpaqueScreenDepthLinear = lightData.opaqueScreenDepthLinear;
                    vec3 refractColor = vec3(0.0);
                    vec2 refractUV = screenUV;

                    if (dot(refractDir, refractDir) > EPSILON) {
                        #if REFRACTION_STRENGTH > 0
                            vec3 refractClipPos = unproject(gbufferProjection * vec4(viewPos + refractDir, 1.0)) * 0.5 + 0.5;
                            
                            vec2 refractOffset = refractClipPos.xy - screenUV;
                            if (length(refractOffset) > 1.0) refractOffset = normalize(refractOffset);

                            float refractDist = max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear - lightData.shadowBias, 0.0);

                            refractOffset *= 4.0 * saturate(2.0 * refractDist);
                            refractUV += refractOffset * 0.01 * REFRACTION_STRENGTH;
                            
                            vec2 alphaXY = saturate(10.0 * abs(vec2(0.5) - refractUV) - 4.0);
                            float rf = smoothstep(0.0, 1.0, 1.0 - maxOf(alphaXY));
                            refractUV = mix(screenUV, refractUV, rf);

                            refractOpaqueScreenDepth = textureLod(depthtex1, refractUV, 0).r;
                            refractOpaqueScreenDepthLinear = linearizeDepthFast(refractOpaqueScreenDepth, near, far);

                            #if WATER_REFRACTION == WATER_REFRACTION_FANCY
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

                                    solidViewDepthLinear = solidViewDepth;//linearizeDepthFast(solidViewDepth, near, far);
                                }
                            #else
                                if (refractOpaqueScreenDepthLinear < lightData.transparentScreenDepthLinear - 0.6*refractDist) {
                                    // reset UV & depths to original point
                                    refractUV = screenUV;
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
                        refractOpaqueScreenDepth = 1.0;
                        refractOpaqueScreenDepthLinear = 65000;
                        //refractColor = vec3(10000.0, 0.0, 0.0);
                    }

                    float waterViewDepthFinal = isEyeInWater == 1 ? lightData.transparentScreenDepthLinear
                        : max(refractOpaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0);

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
                        const float ShadowMaxDepth = far * 3.0;
                    #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                        const float ShadowMaxDepth = 512.0;
                    #else
                        const float ShadowMaxDepth = 256.0;
                    #endif

                    float waterOpaqueShadowDepth = SampleOpaqueDepth(vec4(waterOpaqueShadowPos, 1.0), vec2(0.0));
                    float waterTransparentShadowDepth = SampleTransparentDepth(vec4(waterOpaqueShadowPos, 1.0), vec2(0.0));
                    float waterShadowDepth = max(waterOpaqueShadowPos.z - waterTransparentShadowDepth, 0.0) * ShadowMaxDepth;
                    float waterLightDist = max(waterShadowDepth + waterViewDepthFinal, EPSILON);

                    //uvec4 deferredData = texelFetch(BUFFER_DEFERRED, ivec2(gl_FragCoord.xy), 0);
                    //vec4 waterLightingMap = unpackUnorm4x8(deferredData.a);
                    float waterGeoNoL = 1.0;//waterLightingMap.z * 2.0 - 1.0; //lightData.geoNoL;

                    // TODO: This should be based on the refracted opaque fragment!
                    float waterShadowBias = lightData.shadowBias;

                    if (waterGeoNoL <= 0.0 || waterOpaqueShadowDepth < waterOpaqueShadowPos.z - waterShadowBias)
                        waterLightDist = 2.0 * waterViewDepthFinal;

                    vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterLightDist * extinctionInv);

                    diffuse = refractColor * absorption;

                    ApplyWaterFog(diffuse, lightData, waterViewDepthFinal, -viewDir);
                    
                    diffuse *= max(1.0 - sunF, 0.0);
                    diffuse *= max(1.0 - iblF, 0.0);

                    final.a = saturate(10.0*waterViewDepthFinal - 0.2);
                    //final.a = 1.0;
                #else
                    float waterViewDepth = isEyeInWater == 1 ? lightData.transparentScreenDepthLinear
                        : max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0);

                    float waterLightDist = waterViewDepth + lightData.waterShadowDepth;

                    vec3 absorption = exp(-extinctionInv * waterViewDepth);
                    diffuse *= absorption;
                    //float scatterAmount = exp(-WATER_SCATTER_RATE * waterViewDepth);

                    //vec3 scatterColor = WATER_SCATTER_COLOR * lightData.sunTransmittanceEye;// * skyLight2;// * shadowFinal;

                    //diffuse *= mix(scatterColor, vec3(1.0), scatterAmount) * absorption;

                    float lightDist = isEyeInWater == 1
                        ? min(lightData.opaqueScreenDepthLinear, lightData.transparentScreenDepthLinear)
                        : lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear;

                    float waterFogF = ApplyWaterFog(diffuse, lightData, lightDist, -viewDir);
                    
                    //float alphaF = exp(-0.2 * WATER_ABSROPTION_RATE * waterViewDepth);
                    final.a = waterFogF;//min(final.a + (1.0 - saturate(alphaF)), 1.0);// * (1.0 - material.albedo.a);// * max(1.0 - final.a, 0.0);
                #endif

                ambient = vec3(0.0);
            }
        #endif

        #if defined HANDLIGHT_ENABLED && defined RENDER_DEFERRED
            // TODO: Apply to translucents, but not water!

            if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
                vec3 handDiffuse, handSpecular;
                ApplyHandLighting(handDiffuse, handSpecular, material.albedo.rgb, f0, material.hcm, material.scattering, viewNormal, viewPos.xyz, viewDir, NoVm, roughL);

                diffuse += handDiffuse;
                specular += handSpecular;

                final.a = min(final.a + luminance(handSpecular) * exposure, 1.0);
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

        //diffuse *= 1.0 - saturate(specF);

        final.rgb = final.rgb * (ambient * occlusion)
            + diffuse + emissive
            + (specular + iblSpec) * specularTint;

        final.rgb *= exp(-ATMOS_EXTINCTION * viewDist);

        // #if defined SKY_ENABLED && defined RENDER_DEFERRED
        //     //bool isUnderwater = true;//lightData.shadowPos.z > lightData.transparentShadowDepth && abs(lightData.opaqueShadowDepth - lightData.transparentShadowDepth) > 0.001;

        //     if (isEyeInWater == 1) {
        //         float waterLightDist = max(lightData.opaqueScreenDepthLinear + lightData.waterShadowDepth, 0.0);

        //         const vec3 extinctionInv = 1.0 - WATER_ABSORB_COLOR;
        //         vec3 absorption = exp(-WATER_ABSROPTION_RATE * waterLightDist * extinctionInv);
        //         if (lightData.geoNoL < 0.0 || lightData.opaqueShadowDepth < lightData.shadowPos.z - lightData.shadowBias) absorption = vec3(0.0);

        //         final.rgb *= absorption;
        //     }
        // #endif

        float fogFactor;
        if (isEyeInWater == 1) {
            #ifdef RENDER_WATER
                float lightDist = isEyeInWater == 1
                    ? min(lightData.opaqueScreenDepthLinear, lightData.transparentScreenDepthLinear)
                    : lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear;
            #else
                float lightDist = min(lightData.opaqueScreenDepthLinear, lightData.transparentScreenDepthLinear);
            #endif

            fogFactor = ApplyWaterFog(final.rgb, lightData, lightDist, -viewDir);
        }
        else {
            #ifdef RENDER_WATER
                if (materialId != 100 || isEyeInWater != 1) {
            #endif

            #ifdef RENDER_DEFERRED
                fogFactor = ApplyFog(final.rgb, viewPos, lightData);
            #elif defined RENDER_GBUFFER
                #if defined RENDER_WATER || defined RENDER_HAND_WATER
                    fogFactor = ApplyFog(final, viewPos, lightData, 1.0/255.0);
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
