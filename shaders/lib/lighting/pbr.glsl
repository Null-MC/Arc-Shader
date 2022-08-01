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

        #if defined SHADOW_ENABLED
            tanLightPos = matTBN * shadowLightPosition;
        #endif

        tanViewPos = matTBN * viewPos;

        #ifdef PARALLAX_ENABLED
            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            localCoord = sign(coordNMid) * 0.5 + 0.5;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && (defined RENDER_TERRAIN || defined RENDER_WATER)
            ApplyHardCodedMaterials();
        #endif
    }
#endif

#ifdef RENDER_FRAG
    float F_schlick(const in float cos_theta, const in float f0, const in float f90) {
        float invCosTheta = saturate(1.0 - cos_theta);
        return f0 + (f90 - f0) * pow5(invCosTheta);
    }

    float SchlickRoughness(const in float f0, const in float cos_theta, const in float rough) {
        float invCosTheta = saturate(1.0 - cos_theta);
        return f0 + (max(1.0 - rough, f0) - f0) * pow5(invCosTheta);
    }

    vec3 F_conductor(const in float VoH, const in float n1, const in vec3 n2, const in vec3 k) {
        vec3 eta = n2 / n1;
        vec3 eta_k = k / n1;

        float cos_theta2 = pow2(VoH);
        float sin_theta2 = 1.0f - cos_theta2;
        vec3 eta2 = pow2(eta);
        vec3 eta_k2 = pow2(eta_k);

        vec3 t0 = eta2 - eta_k2 - sin_theta2;
        vec3 a2_plus_b2 = sqrt(t0 * t0 + 4.0f * eta2 * eta_k2);
        vec3 t1 = a2_plus_b2 + cos_theta2;
        vec3 a = sqrt(0.5f * (a2_plus_b2 + t0));
        vec3 t2 = 2.0f * a * VoH;
        vec3 rs = (t1 - t2) / (t1 + t2);

        vec3 t3 = cos_theta2 * a2_plus_b2 + sin_theta2 * sin_theta2;
        vec3 t4 = t2 * sin_theta2;
        vec3 rp = rs * (t3 - t4) / (t3 + t4);

        return 0.5f * (rp + rs);
    }

    float GGX(const in float NoH, const in float roughL) {
        float a = NoH * roughL;
        float k = roughL / (1.0 - pow2(NoH) + pow2(a));
        //return pow2(k) * invPI;
        return min(pow2(k) * invPI, 65504.0);
    }

    float GGX_Fast(const in float NoH, const in vec3 NxH, const in float roughL) {
        float a = NoH * roughL;
        float k = roughL / (dot(NxH, NxH) + pow2(a));
        return min(pow2(k) * invPI, 65504.0);
    }

    float SmithGGXCorrelated(const in float NoV, const in float NoL, const in float roughL) {
        float a2 = pow2(roughL);
        float GGXV = NoL * sqrt(max(NoV * NoV * (1.0 - a2) + a2, EPSILON));
        float GGXL = NoV * sqrt(max(NoL * NoL * (1.0 - a2) + a2, EPSILON));
        return saturate(0.5 / (GGXV + GGXL));
    }

    float SmithGGXCorrelated_Fast(const in float NoV, const in float NoL, const in float roughL) {
        float GGXV = NoL * (NoV * (1.0 - roughL) + roughL);
        float GGXL = NoV * (NoL * (1.0 - roughL) + roughL);
        return saturate(0.5 / (GGXV + GGXL));
    }

    float SmithHable(const in float LoH, const in float alpha) {
        return rcp(mix(pow2(LoH), 1.0, pow2(alpha) * 0.25));
    }

    vec3 GetFresnel(const in vec3 albedo, const in float f0, const in float hcm, const in float VoH, const in float roughL) {
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            if (hcm >= 0) {
                vec3 iorN, iorK;
                GetHCM_IOR(albedo, hcm, iorN, iorK);
                return F_conductor(VoH, IOR_AIR, iorN, iorK);
            }
            else {
                return vec3(SchlickRoughness(f0, VoH, roughL));
            }
        #else
            float dielectric_F = 0.0;
            if (f0 + EPSILON < 1.0)
                dielectric_F = SchlickRoughness(min(f0, 0.04), VoH, roughL);

            vec3 conductor_F = vec3(0.0);
            if (f0 - EPSILON > 0.04) {
                vec3 iorN = vec3(f0ToIOR(albedo));
                vec3 iorK = albedo;

                conductor_F = min(F_conductor(VoH, IOR_AIR, iorN, iorK), 1000.0);
            }

            float metalF = saturate((f0 - 0.04) * (1.0/0.96));
            return mix(vec3(dielectric_F), conductor_F, metalF);
        #endif
    }

    vec3 GetSpecularBRDF(const in vec3 F, const in float NoV, const in float NoL, const in float NoH, const in float roughL) {
        // Fresnel
        //vec3 F = GetFresnel(material, VoH, roughL);

        // Distribution
        float D = GGX(NoH, roughL);

        // Geometric Visibility
        float G = SmithGGXCorrelated_Fast(NoV, NoL, roughL);

        return D * F * G;
    }

    vec3 GetDiffuse_Burley(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
        float f90 = 0.5 + 2.0 * roughL * pow2(LoH);
        float light_scatter = F_schlick(NoL, 1.0, f90);
        float view_scatter = F_schlick(NoV, 1.0, f90);
        return (albedo * invPI) * light_scatter * view_scatter * NoL;
    }

    vec3 GetSubsurface(const in vec3 albedo, const in float NoVm, const in float NoL, const in float LoHm, const in float roughL) {
        float NoLm = max(NoL, 0.0);

        float sssF90 = roughL * pow2(LoHm);
        float sssF_In = F_schlick(NoVm, 1.0, sssF90);
        float sssF_Out = F_schlick(NoLm, 1.0, sssF90);

        // TODO: modified this to prevent NaN's!
        //return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (1.0 / (NoVm + NoLm) - 0.5) + 0.5) * abs(NoL);
        vec3 result = (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (min(1.0 / max(NoVm + NoLm, 0.0001), 1.0) - 0.5) + 0.5);// * abs(NoL);
        //return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (rcp(1.0 + (NoV + NoL)) - 0.5) + 0.5);

        #ifndef SHADOW_ENABLED
            result *= abs(NoL);
        #endif

        return result;
    }

    vec3 GetDiffuseBSDF(const in vec3 diffuse, const in vec3 albedo, const in float scattering, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
        //vec3 diffuse = GetDiffuse_Burley(material.albedo.rgb, NoV, NoL, LoH, roughL);

        #ifdef SSS_ENABLED
            if (scattering < EPSILON) return diffuse;

            vec3 subsurface = GetSubsurface(albedo, NoV, NoL, LoH, roughL);
            return mix(diffuse, subsurface, scattering);
        #else
            return diffuse;
        #endif
    }


    // Common Usage Pattern

    #ifdef HANDLIGHT_ENABLED
        float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
            float diffuseAtt = max(0.0625*lightLevel - 0.08*lightDist, 0.0);
            return pow5(diffuseAtt);
        }

        void ApplyHandLighting(out vec3 diffuse, out vec3 specular, const in vec3 albedo, const in float f0, const in float hcm, const in float scattering, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL) {
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

    vec4 PbrLighting2(const in PbrMaterial material, const in vec3 shadowColorMap, const in vec2 lmValue, const in float shadow, const in float shadowSSS, const in vec3 viewPos, const in vec2 waterSolidDepth) {
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
                float noise = textureLod(noisetex, 0.22*localPos.xz, 0).r;
                wetnessFinal *= noise * 0.2 + 0.8;

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

        float shadowFinal = shadow;
        #ifdef LIGHTLEAK_FIX
            // Make areas without skylight fully shadowed (light leak fix)
            float lightLeakFix = step(skyLight, EPSILON);
            shadowFinal *= lightLeakFix;
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            // Increase skylight when in direct sunlight
            skyLight = max(skyLight, shadow);
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
                    int maxHdrPrevLod = textureQueryLevels(BUFFER_HDR_PREVIOUS);

                    int lod = int(rough * maxHdrPrevLod);
                    vec4 roughReflectColor = GetReflectColor(depthtex1, viewPos, reflectDir, lod);
                    reflectColor = (roughReflectColor.rgb / exposure) * roughReflectColor.a;

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
            #if RSM_SCALE == 0 || defined RSM_UPSCALE
                //ivec2 iuv = ivec2(texcoord * viewSize);
                vec3 rsmColor = texelFetch(BUFFER_RSM_COLOR, ivec2(gl_FragCoord.xy), 0).rgb;
            #else
                const float rsm_scale = 1.0 / exp2(RSM_SCALE);
                vec3 rsmColor = textureLod(BUFFER_RSM_COLOR, texcoord * rsm_scale, 0).rgb;
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
                    //envBRDF = RGBToLinear(vec3(envBRDF, 0.0)).rg;
                #endif

                iblF = GetFresnel(material.albedo.rgb, f0, material.hcm, NoVm, rough);
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
            vec3 skyAmbient = GetSkyAmbientLight(viewNormal) * ambientBrightness;
            ambient += skyAmbient;
            //return vec4(ambient, 1.0);

            vec3 skyLightColorFinal = skyLightColor * shadowColorMap;
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

        float emissive = material.emission*material.emission * EmissionLumens;

        // #ifdef RENDER_WATER
        //     //ambient = vec3(0.0);
        //     diffuse = vec3(0.0);
        //     specular = vec3(0.0);
        // #endif

        //return vec4(diffuse, 1.0);

        final.rgb = final.rgb * (ambient * max(1.0 - iblF, vec3(0.0)) * material.occlusion + emissive)
            + diffuse * material.albedo.a
            + (specular + iblSpec) * specularTint;

        // #ifdef SSS_ENABLED
        //     //float ambientShadowBrightness = 1.0 - 0.5 * (1.0 - SHADOW_BRIGHTNESS);
        //     vec3 ambient_sss = skyAmbient * material.scattering * material.occlusion;

        //     // Transmission
        //     vec3 sss = (1.0 - shadowFinal) * shadowSSS * material.scattering * skyLightColorFinal;// * max(-NoL, 0.0);
        //     final.rgb += material.albedo.rgb * invPI * (ambient_sss + sss);
        // #endif

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
            vec3 shadowViewStart = unproject(matViewToShadowView * vec4(vec3(0.0), 1.0));
            vec3 shadowViewEnd = unproject(matViewToShadowView * vec4(viewPos, 1.0));

            float shadowBias = 0.0;//-1e-2; // TODO: fuck

            float scattering = GetScatteringFactor();

            #ifdef SHADOW_COLOR
                vec3 volScatter = GetVolumetricLightingColor(shadowViewStart, shadowViewEnd, shadowBias, scattering);
            #else
                float volScatter = GetVolumetricLighting(shadowViewStart, shadowViewEnd, shadowBias, scattering);
            #endif

            vec3 volLight = volScatter * (sunColor + moonColor) * (0.01 * VL_STRENGTH);

            //final.a = min(final.a + luminance(volLight) * exposure, 1.0);
            final.rgb += volLight;
        #endif

        return final;
    }
#endif
