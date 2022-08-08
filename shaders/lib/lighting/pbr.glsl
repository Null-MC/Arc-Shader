#ifdef RENDER_VERTEX
    void PbrVertex(const in vec3 viewPos) {
        //vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
        viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
        vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * at_tangent.w);
        tangentW = at_tangent.w;

        mat3 matTBN = mat3(
            viewTangent.x, viewBinormal.x, viewNormal.x,
            viewTangent.y, viewBinormal.y, viewNormal.y,
            viewTangent.z, viewBinormal.z, viewNormal.z);

        #ifdef PARALLAX_ENABLED
            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            localCoord = sign(coordNMid) * 0.5 + 0.5;

            #if defined SHADOW_ENABLED
                tanLightPos = matTBN * shadowLightPosition;
            #endif

            tanViewPos = matTBN * viewPos;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && (defined RENDER_TERRAIN || defined RENDER_WATER)
            ApplyHardCodedMaterials();
        #endif
    }
#endif

#ifdef RENDER_FRAG
    #ifdef HANDLIGHT_ENABLED
        float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
            float diffuseAtt = max(0.0625*lightLevel - 0.08*lightDist, 0.0);
            return pow5(diffuseAtt);
        }

        void ApplyHandLighting(out vec3 diffuse, out vec3 specular, const in vec3 albedo, const in float f0, const in int hcm, const in float scattering, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL) {
            vec3 lightPos = handOffset - viewPos.xyz;
            vec3 lightDir = normalize(lightPos);

            float NoL = dot(viewNormal, lightDir);
            float NoLm = max(NoL, 0.0);

            float lightDist = length(lightPos);
            float attenuation = GetHandLightAttenuation(heldBlockLightValue, lightDist);
            if (attenuation < EPSILON) {
                diffuse = vec3(0.0);
                specular = vec3(0.0);
                return;
            }

            vec3 halfDir = normalize(lightDir + viewDir);
            float LoHm = max(dot(lightDir, halfDir), 0.0);

            vec3 handLightColor = blockLightColor * attenuation;

            vec3 F = GetFresnel(albedo, f0, hcm, LoHm, roughL);
            vec3 handDiffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL) * max(1.0 - F, 0.0);
            diffuse = GetDiffuseBSDF(handDiffuse, albedo, scattering, NoVm, NoL, LoHm, roughL) * handLightColor;

            if (NoLm < EPSILON) {
                specular = vec3(0.0);
                return;
            }
            
            float NoHm = max(dot(viewNormal, halfDir), 0.0);
            specular = GetSpecularBRDF(F, NoVm, NoLm, NoHm, roughL) * handLightColor;
        }
    #endif

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
        vec3 GetSkyReflectionColor(const in vec3 reflectDir) {
            // darken lower horizon
            vec3 downDir = normalize(-upPosition);
            float RoDm = max(dot(reflectDir, downDir), 0.0);
            float reflectF = 1.0 - RoDm;

            // occlude inward reflections
            //float NoRm = max(dot(reflectDir, -viewNormal), 0.0);
            //reflectF *= 1.0 - pow(NoRm, 0.5);

            vec3 skyLumen = GetVanillaSkyLuminance(reflectDir);
            vec3 skyScatter = GetVanillaSkyScattering(reflectDir, sunColor, moonColor);

            // TODO: clamp skyScatter?
            //skyScatter = min(skyScatter, 65554.0);

            return (skyLumen + skyScatter) * reflectF;
            //return skyLumen * reflectF;
        }
    #endif

    #if defined SKY_ENABLED && defined RSM_ENABLED && defined RSM_UPSCALE && defined RENDER_DEFERRED
        vec3 GetUpscaledRSM(const in vec3 shadowViewPos, const in vec3 shadowViewNormal, const in float depthLinear, const in vec2 screenUV, const in float skyLight) {
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
                #ifdef LIGHTLEAK_FIX
                    vec3 final  vec3(0.0);
                    if (skyLight >= 1.0 / 16.0)
                        final = GetIndirectLighting_RSM(shadowViewPos, shadowViewNormal);
                #else
                    vec3 final = GetIndirectLighting_RSM(shadowViewPos, shadowViewNormal);
                #endif

                //final = mix(final, vec3(600.0, 0.0, 0.0), 0.25);
                return final;
            }
        }
    #endif

    vec4 PbrLighting2(const in PbrMaterial material, const in vec2 lmValue, const in float geoNoL, const in vec3 viewPos, const in SHADOW_POS_TYPE, const in vec2 waterSolidDepth) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = -normalize(viewPos);
        float viewDist = length(viewPos);

        vec2 screenUV = gl_FragCoord.xy / viewSize;

        //return vec4((material.normal * 0.5 + 0.5) * 500.0, 1.0);

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

        //vec3 localNormal = mat3(gbufferModelViewInverse) * viewNormal;
        //return vec4(localNormal * 1000.0, 1.0);

        float blockLight = saturate((lmValue.x - (1.0/16.0 + EPSILON)) / (15.0/16.0));
        float skyLight = saturate((lmValue.y - (1.0/16.0 + EPSILON)) / (15.0/16.0));

        vec3 viewUpDir = normalize(upPosition);
        // float wetness_NoU = dot(viewNormal, viewUpDir) * 0.4 + 0.6;
        // float wetness_skyLight = max((skyLight - (14.0/16.0)) * 16.0, 0.0);
        // float wetnessFinal = wetness * wetness_skyLight * wetness_NoU;
        float wetnessFinal = GetDirectionalWetness(viewNormal, skyLight);

        vec3 albedo = material.albedo.rgb;
        float smoothness = material.smoothness;
        float f0 = material.f0;

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

        float rough = 1.0 - smoothness;
        float roughL = max(rough * rough, 0.005);



        float shadow = 1.0;
        float shadowSSS = 0.0;
        vec3 shadowColor = vec3(1.0);

        #ifdef SKY_ENABLED
            shadow *= step(EPSILON, geoNoL);
            shadow *= step(EPSILON, NoL);

            //float NoL = dot(viewNormal, viewLightDir);

            #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                // vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos, 1.0))).xyz;

                // #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                //     vec3 shadowPos[4];
                //     for (int i = 0; i < 4; i++) {
                //         shadowPos[i] = (matShadowProjections[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                        
                //         vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                //         shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;
                //     }
                // #else
                //     vec4 shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);
                //     //float shadowBias = 0.0;//-1e-2; // TODO: fuck

                //     #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                //         float distortFactor = getDistortFactor(shadowPos.xy);
                //         shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
                //         float shadowBias = GetShadowBias(geoNoL, distortFactor);
                //     #elif SHADOW_TYPE == SHADOW_TYPE_BASIC
                //         float shadowBias = GetShadowBias(geoNoL);
                //     #endif

                //     shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
                // #endif

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    float distortFactor = getDistortFactor(shadowPos.xy);
                    float shadowBias = GetShadowBias(geoNoL, distortFactor);
                #elif SHADOW_TYPE == SHADOW_TYPE_BASIC
                    float shadowBias = GetShadowBias(geoNoL);
                #endif

                if (shadow > EPSILON) {
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        shadow *= GetShadowing(shadowPos);
                    #else
                        shadow *= GetShadowing(shadowPos, shadowBias);
                    #endif
                }

                #ifdef SHADOW_COLOR
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        shadowColor = GetShadowColor(shadowPos);
                    #else
                        shadowColor = GetShadowColor(shadowPos.xyz, shadowBias);
                    #endif
                    
                    shadowColor = RGBToLinear(shadowColor);
                #endif

                #ifdef SSS_ENABLED
                    if (material.scattering > EPSILON) {
                        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                            shadowSSS = GetShadowSSS(shadowPos);
                        #else
                            shadowSSS = GetShadowSSS(shadowPos, shadowBias);
                        #endif
                    }
                #endif

                // #ifdef PARALLAX_SHADOWS_ENABLED
                //     if (shadow > EPSILON && traceCoordDepth.z + EPSILON < 1.0) {
                //         #ifdef PARALLAX_USE_TEXELFETCH
                //             shadow *= GetParallaxShadow(traceCoordDepth, tanLightDir);
                //         #else
                //             shadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);
                //         #endif
                //     }
                // #endif
            #endif
        #endif




        float shadowFinal = shadow;
        //return vec4(vec3(shadow * 800.0), 1.0);

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

        //float reflectF = 0.0;
        vec3 reflectColor = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            if (smoothness > EPSILON) {
                vec3 reflectDir = reflect(-viewDir, viewNormal);

                #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
                    // TODO: move to vertex shader!
                    int maxHdrPrevLod = 4;//textureQueryLevels(BUFFER_HDR_PREVIOUS);

                    int lod = int(rough * max(maxHdrPrevLod - 0.5, 0.0));
                    vec4 roughReflectColor = GetReflectColor(depthtex1, viewPos, reflectDir, lod);
                    reflectColor = roughReflectColor.rgb / exposure * roughReflectColor.a;
                    //reflectColor = clamp(reflectColor, vec3(0.0), vec3(65000.0));

                    #ifdef SKY_ENABLED
                        if (roughReflectColor.a + EPSILON < 1.0) {
                            vec3 skyReflectColor = GetSkyReflectionColor(reflectDir) * skyLight3;
                            reflectColor += skyReflectColor * (1.0 - roughReflectColor.a);
                        }
                    #endif

                #elif REFLECTION_MODE == REFLECTION_MODE_SKY && defined SKY_ENABLED
                    reflectColor = GetSkyReflectionColor(reflectDir) * skyLight3;
                #endif
            }
        #endif

        //return vec4(reflectColor, 1.0);

        #if defined SKY_ENABLED && defined RSM_ENABLED && defined RENDER_DEFERRED
            //vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos, 1.0))).xyz;
            vec3 shadowViewNormal = mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * viewNormal);

            vec2 tex = screenUV;

            #ifndef IS_OPTIFINE
                tex /= exp2(RSM_SCALE);
            #endif

            #ifdef RSM_UPSCALE
                vec3 rsmColor = GetUpscaledRSM(shadowViewPos, shadowViewNormal, -viewPos.z, tex, skyLight);
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

        vec3 ambient = vec3(MinWorldLux + blockLightAmbient);
        vec3 diffuse = vec3(0.0);
        vec3 specular = vec3(0.0);
        vec4 final = vec4(albedo, material.albedo.a);

        vec3 iblF = vec3(0.0);
        vec3 iblSpec = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            if (any(greaterThan(reflectColor, vec3(EPSILON)))) {
                vec2 envBRDF = textureLod(BUFFER_BRDF_LUT, vec2(NoVm, rough), 0).rg;

                #ifndef IS_OPTIFINE
                    envBRDF = RGBToLinear(vec3(envBRDF, 0.0)).rg;
                #endif

                iblF = GetFresnel(material.albedo.rgb, f0, material.hcm, NoVm, roughL);
                iblSpec = reflectColor * (iblF * envBRDF.x + envBRDF.y) * material.occlusion;
                //iblSpec = reflectColor * mix(envBRDF.xxx, envBRDF.yyy, iblF) * material.occlusion;

                //iblSpec = min(iblSpec, 100000.0);

                float iblFmax = max(max(iblF.x, iblF.y), iblF.z);
                final.a += iblFmax * max(1.0 - final.a, 0.0);
            }
        #endif

        //return vec4(vec3(NoVm * 1000.0), 1.0);
        //return vec4(iblSpec, 1.0);

        #ifdef SKY_ENABLED
            float ambientBrightness = mix(0.36 * skyLight2, 0.95 * skyLight, rainStrength); // SHADOW_BRIGHTNESS
            vec3 skyAmbient = GetSkyAmbientLight(viewNormal);
            ambient += skyAmbient * ambientBrightness;
            //return vec4(ambient, 1.0);

            vec3 skyLightColorFinal = skyLightColor * shadowColor;
            float diffuseLightF = shadowFinal;

            #ifdef SSS_ENABLED
                //float ambientShadowBrightness = 1.0 - 0.5 * (1.0 - SHADOW_BRIGHTNESS);
                //vec3 ambient_sss = skyAmbient * material.scattering * material.occlusion;

                // Transmission
                //vec3 sss = shadowSSS * material.scattering * skyLightColorFinal;// * max(-NoL, 0.0);
                //diffuseLightF = mix(diffuseLightF, shadowSSS*2.0, material.scattering);
                diffuseLightF = max(diffuseLightF, min(shadowSSS, 1.0));
            #endif

            vec3 diffuseLight = diffuseLightF * skyLightColorFinal * skyLight2;

            //#if defined RSM_ENABLED && defined RENDER_DEFERRED
            //    diffuseLight += 20.0 * rsmColor * skyLightColorFinal * material.scattering;
            //#endif

            vec3 sunF = GetFresnel(material.albedo.rgb, f0, material.hcm, LoHm, roughL);
            vec3 sunDiffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL) * max(1.0 - sunF, 0.0);
            sunDiffuse = GetDiffuseBSDF(sunDiffuse, albedo, material.scattering, NoVm, NoL, LoHm, roughL) * diffuseLight;
            diffuse += sunDiffuse * material.albedo.a;

            if (NoLm > EPSILON) {
                float NoHm = max(dot(viewNormal, halfDir), 0.0);

                vec3 sunSpec = GetSpecularBRDF(sunF, NoVm, NoLm, NoHm, roughL) * skyLightColorFinal * skyLight2 * shadowFinal;
                
                specular += sunSpec;// * material.albedo.a;

                final.a = min(final.a + luminance(sunSpec) * exposure, 1.0);
            }
        #endif

        #if defined RENDER_WATER && !defined WORLD_NETHER
            if (materialId == 1) {
                const float ScatteringCoeff = 0.11;

                //vec3 extinction = vec3(0.54, 0.91, 0.93);
                vec3 extinctionInv = 1.0 - WaterAbsorbtionExtinction;
                //vec3 extinction = 1.0 - material.albedo.rgb;

                #if WATER_REFRACTION != WATER_REFRACTION_NONE
                    float waterRefractEta = isEyeInWater == 1
                        ? IOR_WATER / IOR_AIR
                        : IOR_AIR / IOR_WATER;
                    
                    float refractDist = max(waterSolidDepth.y - waterSolidDepth.x, 0.0);

                    vec2 waterSolidDepthFinal;
                    vec3 refractColor = vec3(0.0);
                    vec3 refractDir = refract(vec3(0.0, 0.0, -1.0), viewNormal, waterRefractEta); // TODO: subtract geoViewNormal from texViewNormal
                    if (dot(refractDir, refractDir) > EPSILON) {
                        vec2 refractOffset = refractDir.xy;

                        // scale down contact point to avoid tearing
                        refractOffset *= min(0.1*refractDist, 0.06);

                        // scale down with distance
                        refractOffset *= pow2(1.0 - saturate((viewDist - near) / (far - near)));
                        
                        vec2 refractUV = screenUV + refractOffset;

                        // update water depth
                        waterSolidDepthFinal = GetWaterSolidDepth(refractUV);

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

                                waterSolidDepthFinal.y = solidViewDepth;//linearizeDepthFast(solidViewDepth, near, far);
                            }
                        #else
                            if (waterSolidDepthFinal.y < waterSolidDepthFinal.x) {
                                // refracted vector returned an invalid hit
                                waterSolidDepthFinal = waterSolidDepth;
                                refractUV = screenUV;

                            }
                        #endif

                        refractColor = textureLod(BUFFER_REFRACT, refractUV, 0).rgb / exposure;
                    }
                    else {
                        // TIR
                        waterSolidDepthFinal.x = 65000;
                        waterSolidDepthFinal.y = 65000;
                    }

                    float waterDepthFinal = isEyeInWater == 1 ? waterSolidDepthFinal.x
                        : max(waterSolidDepthFinal.y - waterSolidDepthFinal.x, 0.0);

                    vec3 scatterColor = material.albedo.rgb * skyLightColorFinal * skyLight2;// * shadowFinal;

                    float verticalDepth = waterDepthFinal * max(dot(viewLightDir, viewUpDir), 0.0);
                    vec3 absorption = exp(extinctionInv * -(verticalDepth + waterDepthFinal));
                    float inverseScatterAmount = 1.0 - exp(0.06 * -waterDepthFinal);

                    diffuse = (refractColor + scatterColor * inverseScatterAmount) * absorption;
                    final.a = 1.0;
                #else
                    //float waterSurfaceDepth = textureLod(shadowtex0);
                    //float solidSurfaceDepth = textureLod(shadowtex1);

                    float waterDepth = isEyeInWater == 1 ? waterSolidDepth.x
                        : max(waterSolidDepth.y - waterSolidDepth.x, 0.0);

                    vec3 scatterColor = material.albedo.rgb * skyLightColorFinal * skyLight2;// * shadowFinal;

                    float verticalDepth = waterDepth * max(dot(viewLightDir, viewUpDir), 0.0);
                    vec3 absorption = exp(extinctionInv * -(waterDepth + verticalDepth));
                    float scatterAmount = exp(0.01 * -waterDepth);

                    //diffuse = (diffuse + scatterColor * scatterAmount);// * absorption;
                    diffuse = scatterColor * scatterAmount + absorption;
                    
                    float alphaF = 1.0 - exp(2.0 * -waterDepth);
                    final.a += alphaF * max(1.0 - final.a, 0.0);
                    //final.a = 1.0;
                #endif
            }
        #endif

        #if defined HANDLIGHT_ENABLED && !defined RENDER_HAND && !defined RENDER_HAND_WATER
            if (heldBlockLightValue > EPSILON) {
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

                diffuse *= HCM_AMBIENT;
                ambient *= HCM_AMBIENT;
            }
        #else
            float metalDarkF = 1.0 - material.f0 * (1.0 - HCM_AMBIENT);
            diffuse *= metalDarkF;
            ambient *= metalDarkF;
        #endif

        //ambient += minLight;

        float emissive = pow4(material.emission) * EmissionLumens;

        // #ifdef RENDER_WATER
        //     //ambient = vec3(0.0);
        //     diffuse = vec3(0.0);
        //     specular = vec3(0.0);
        // #endif

        //return vec4(diffuse, 1.0);

        //ambient *= max(1.0 - iblF, vec3(0.0));
        //return vec4((iblSpec) * specularTint, 1.0);

        #ifdef SSS_ENABLED
            //float ambientShadowBrightness = 1.0 - 0.5 * (1.0 - SHADOW_BRIGHTNESS);
            //vec3 ambient_sss = skyAmbient * skyLight2 * material.scattering;
            //ambient += invPI * ambient_sss;
        #endif

        //return vec4(ambient, 1.0);

        final.rgb = final.rgb * (ambient * material.occlusion + emissive)
            + diffuse * material.albedo.a
            + (specular + iblSpec) * specularTint;

        #ifdef RENDER_DEFERRED
            if (isEyeInWater == 1) {
                // apply scattering and absorption

                //float viewDepthLinear = linearizeDepthFast(gl_FragCoord.z, near, far);
                float viewDepth = textureLod(depthtex1, screenUV, 0).r;
                float viewDepthLinear = linearizeDepthFast(viewDepth, near, far);

                //float waterDepthFinal = isEyeInWater == 1 ? waterSolidDepthFinal.x
                //    : max(waterSolidDepthFinal.y - waterSolidDepthFinal.x, 0.0);

                //vec3 scatterColor = material.albedo.rgb * skyLightColorFinal;// * shadowFinal;
                //float skyLight5 = pow5(skyLight);
                float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);
                vec3 scatterColor = vec3(0.0178, 0.0566, 0.0754) * skyLight2 * pow3(eyeLight);// * shadowFinal;
                vec3 extinctionInv = 1.0 - WaterAbsorbtionExtinction;

                //float verticalDepth = waterDepthFinal * max(dot(viewLightDir, viewUpDir), 0.0);
                //vec3 absorption = exp(extinctionInv * -(verticalDepth + waterDepthFinal));
                vec3 absorption = exp(extinctionInv * -viewDepthLinear);
                float inverseScatterAmount = 1.0 - exp(0.11 * -viewDepthLinear);

                final.rgb = (final.rgb + scatterColor * inverseScatterAmount) * absorption;

                //float vanillaWaterFogF = GetFogFactor(viewDist, near, waterFogEnd, 1.0);
                //final.rgb = mix(final.rgb, RGBToLinear(fogColor), vanillaWaterFogF);
            }
        #endif

        //float waterDepth = textureLod(shadowtex0, shadowPos, 0);
        //waterDepth = (waterDepth * 2.0 - 1.0) * far * 2.0;

        if (isEyeInWater == 1) {
            float eyeLight = saturate(eyeBrightnessSmooth.y / 240.0);

            #ifdef SKY_ENABLED
                // TODO: Get this outa here (vertex shader)
                vec2 skyLightLevels = GetSkyLightLevels();
                vec3 skyLightLuxColor = GetSkyLightLuxColor(skyLightLevels);
            #else
                vec3 skyLightLuxColor = vec3(100.0);
            #endif

            // apply water fog
            float waterFogEnd = min(40.0, fogEnd);
            float waterFogF = GetFogFactor(viewDist, near, waterFogEnd, 0.5);
            vec3 waterFogColor = vec3(0.0178, 0.0566, 0.0754) * skyLightLuxColor * (0.02 + 0.98*eyeLight);
            final.rgb = mix(final.rgb, waterFogColor, waterFogF);
        }
        else {
            #ifdef RENDER_DEFERRED
                ApplyFog(final.rgb, viewPos, skyLight);
            #elif defined RENDER_GBUFFER
                #if defined RENDER_WATER || defined RENDER_HAND_WATER
                    ApplyFog(final, viewPos, skyLight, EPSILON);
                #else
                    ApplyFog(final, viewPos, skyLight, alphaTestRef);
                #endif
            #endif
        }

        #if defined SKY_ENABLED && defined VL_ENABLED
            mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
            vec3 shadowViewStart = (matViewToShadowView * vec4(vec3(0.0, 0.0, -near), 1.0)).xyz;
            vec3 shadowViewEnd = (matViewToShadowView * vec4(viewPos, 1.0)).xyz;

            float scattering = GetScatteringFactor();

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                // TODO: get rid of this lazy useless hack
                float shadowBias = 0.0;
            #endif

            #ifdef SHADOW_COLOR
                vec3 volScatter = GetVolumetricLightingColor(shadowViewStart, shadowViewEnd, shadowBias, scattering);
            #else
                float volScatter = GetVolumetricLighting(shadowViewStart, shadowViewEnd, shadowBias, scattering);
            #endif

            vec3 volLight = volScatter * (sunColor + moonColor);

            //final.a = min(final.a + luminance(volLight) * exposure, 1.0);
            final.rgb += volLight;
        #endif

        return final;
    }
#endif
