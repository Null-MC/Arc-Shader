#ifdef RENDER_VERTEX
    void PbrVertex(const in mat3 matViewTBN) {
        #ifdef PARALLAX_ENABLED
            tanViewPos = matViewTBN * viewPos;

            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            localCoord = sign(coordNMid) * 0.5 + 0.5;
        #endif
    }
#endif

#ifdef RENDER_FRAG
    float F_schlick(const in float cos_theta, const in float f0, const in float f90)
    {
        return f0 + (f90 - f0) * pow(1.0 - cos_theta, 5.0);
    }

    float SchlickRoughness(const in float f0, const in float cos_theta, const in float rough) {
        return f0 + (max(1.0 - rough, f0) - f0) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0);
    }

    vec3 F_conductor(const in float VoH, const in float n1, const in vec3 n2, const in vec3 k)
    {
        vec3 eta = n2 / n1;
        vec3 eta_k = k / n1;

        float cos_theta2 = VoH * VoH;
        float sin_theta2 = 1.0f - cos_theta2;
        vec3 eta2 = eta * eta;
        vec3 eta_k2 = eta_k * eta_k;

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

    float GGX(const in float NoH, const in float roughL)
    {
        const float a = NoH * roughL;
        const float k = roughL / (1.0 - NoH * NoH + a * a);
        return k * k * (1.0 / PI);
    }

    float GGX_Fast(const in float NoH, const in vec3 NxH, const in float roughL)
    {
        float a = NoH * roughL;
        float k = roughL / (dot(NxH, NxH) + a * a);
        return min(k * k * invPI, 65504.0);
    }

    float SmithGGXCorrelated(const in float NoV, const in float NoL, const in float roughL) {
        float a2 = roughL * roughL;
        float GGXV = NoL * sqrt(max(NoV * NoV * (1.0 - a2) + a2, EPSILON));
        float GGXL = NoV * sqrt(max(NoL * NoL * (1.0 - a2) + a2, EPSILON));
        return clamp(0.5 / (GGXV + GGXL), 0.0, 1.0);
    }

    float SmithGGXCorrelated_Fast(const in float NoV, const in float NoL, const in float roughL) {
        float GGXV = NoL * (NoV * (1.0 - roughL) + roughL);
        float GGXL = NoV * (NoL * (1.0 - roughL) + roughL);
        return clamp(0.5 / (GGXV + GGXL), 0.0, 1.0);
    }

    float SmithHable(const in float LdotH, const in float alpha)
    {
        return 1.0 / mix(LdotH * LdotH, 1.0, alpha * alpha * 0.25);
    }

    vec3 GetFresnel(const in PbrMaterial material, const in float VoH, const in float roughL) {
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
            if (material.hcm >= 0) {
                vec3 iorN, iorK;
                GetHCM_IOR(material.albedo.rgb, material.hcm, iorN, iorK);
                return F_conductor(VoH, IOR_AIR, iorN, iorK);
            }
            else {
                return vec3(SchlickRoughness(material.f0, VoH, roughL));
            }
        #else
            float dielectric_F = 0.0;
            if (material.f0 + EPSILON < 1.0)
                dielectric_F = SchlickRoughness(0.04, VoH, roughL);

            vec3 conductor_F = vec3(0.0);
            if (material.f0 - EPSILON > 0.04) {
                vec3 iorN = vec3(f0ToIOR(material.albedo.rgb));
                vec3 iorK = material.albedo.rgb;

                conductor_F = F_conductor(VoH, IOR_AIR, iorN, iorK);
            }

            float metalF = clamp((material.f0 - 0.04) * (1.0/0.96), 0.0, 1.0);
            return mix(vec3(dielectric_F), conductor_F, metalF);
        #endif
    }

    vec3 GetSpecularBRDF(const in vec3 F, const in float NoV, const in float NoL, const in float NoH, const in float roughL)
    {
        // Fresnel
        //vec3 F = GetFresnel(material, VoH, roughL);

        // Distribution
        float D = GGX(NoH, roughL);

        // Geometric Visibility
        //float G = SmithHable(LoH, roughL);
        float G = SmithGGXCorrelated(NoV, NoL, roughL);

        //return clamp(D * F * G, 0.0, 100000.0);
        return D * F * G;
    }

    vec3 GetDiffuse_Burley(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL)
    {
        float f90 = 0.5 + 2.0 * roughL * LoH * LoH;
        float light_scatter = F_schlick(NoL, 1.0, f90);
        float view_scatter = F_schlick(NoV, 1.0, f90);
        return (albedo * invPI) * light_scatter * view_scatter * NoL;
    }

    vec3 GetSubsurface(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
        float sssF90 = roughL * pow(LoH, 2);
        float sssF_In = F_schlick(NoV, 1.0, sssF90);
        float sssF_Out = F_schlick(NoL, 1.0, sssF90);

        return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (1.0 / (NoV + NoL) - 0.5) + 0.5) * NoL;
    }

    vec3 GetDiffuseBSDF(const in PbrMaterial material, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
        vec3 diffuse = GetDiffuse_Burley(material.albedo.rgb, NoV, NoL, LoH, roughL);

        #ifdef SSS_ENABLED
            if (material.scattering < EPSILON) return diffuse;

            vec3 subsurface = GetSubsurface(material.albedo.rgb, NoV, NoL, LoH, roughL);
            return (1.0 - material.scattering) * diffuse + material.scattering * subsurface;
        #else
            return diffuse;
        #endif
    }


    // Common Usage Pattern

    #ifdef HANDLIGHT_ENABLED
        float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
            float diffuseAtt = max(0.0625*lightLevel - 0.08*lightDist, 0.0);
            return pow(diffuseAtt, 5.0);
        }

        void ApplyHandLighting(inout vec3 diffuse, inout vec3 specular, const in PbrMaterial material, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL) {
            vec3 lightPos = handOffset - viewPos.xyz;
            vec3 lightDir = normalize(lightPos);

            float NoLm = max(dot(viewNormal, lightDir), 0.0);
            if (NoLm < EPSILON) return;

            float lightDist = length(lightPos);
            float attenuation = GetHandLightAttenuation(heldBlockLightValue, lightDist);
            if (attenuation < EPSILON) return;

            vec3 halfDir = normalize(lightDir + viewDir);
            float LoHm = max(dot(lightDir, halfDir), EPSILON);
            float NoHm = max(dot(viewNormal, halfDir), EPSILON);
            float VoHm = max(dot(viewDir, halfDir), EPSILON);

            vec3 handLightColor = blockLightColor * attenuation;

            vec3 F = GetFresnel(material, VoHm, roughL);

            diffuse += GetDiffuseBSDF(material, NoVm, NoLm, LoHm, roughL) * handLightColor;
            specular += GetSpecularBRDF(F, NoVm, NoLm, NoHm, roughL) * handLightColor;
        }
    #endif

    vec4 PbrLighting2(const in PbrMaterial material, const in vec2 lmValue, const in float shadow, const in float shadowSSS, const in vec3 viewPos) {
        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = -normalize(viewPos.xyz);

        #ifdef SHADOW_ENABLED
            vec3 viewLightDir = normalize(shadowLightPosition);
            float NoL = dot(viewNormal, viewLightDir);

            vec3 halfDir = normalize(viewLightDir + viewDir);
            float LoHm = max(dot(viewLightDir, halfDir), EPSILON);
        #else
            float NoL = 1.0;
            float LoHm = 1.0;
        #endif

        float NoLm = max(NoL, EPSILON);
        float NoVm = max(dot(viewNormal, viewDir), EPSILON);

        float rough = 1.0 - material.smoothness;
        float roughL = max(rough * rough, 0.005);

        float blockLight = clamp((lmValue.x - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
        float skyLight = clamp((lmValue.y - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);

        // Increase skylight when in direct sunlight
        skyLight = max(skyLight, shadow);

        // Make areas without skylight fully shadowed (light leak fix)
        float lightLeakFix = step(1.0 / 32.0, skyLight);
        float shadowFinal = shadow * lightLeakFix;

        float skyLight5 = pow(skyLight, 5.0);

        float reflectF = 0.0;
        vec3 reflectColor = vec3(0.0);
        if (material.smoothness > EPSILON) {
            vec3 reflectDir = normalize(reflect(-viewDir, viewNormal));

            #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
                //vec2 reflectCoord = GetReflectCoord(reflectDir);

                vec2 reflectionUV;
                float atten = GetReflectColor(texcoord, depth, viewPos, reflectDir, reflectionUV);

                if (atten > EPSILON) {
                    ivec2 iReflectUV = ivec2(reflectionUV * 0.5 * vec2(viewWidth, viewHeight));
                    reflectColor = texelFetch(BUFFER_HDR_PREVIOUS, iReflectUV, 0) / max(exposure, EPSILON);
                }

                if (atten + EPSILON < 1.0) {
                    vec3 skyColor = GetVanillaSkyLux(reflectDir);
                    reflectColor = mix(skyColor, reflectColor, atten);
                }
            #elif REFLECTION_MODE == REFLECTION_MODE_SKY
                // darken lower horizon
                vec3 downDir = normalize(-upPosition);
                float RoDm = max(dot(reflectDir, downDir), 0.0);
                reflectF = 1.0 - pow(RoDm, 0.5);

                // occlude inward reflections
                float NoRm = max(dot(reflectDir, -viewNormal), 0.0);
                reflectF *= 1.0 - pow(NoRm, 0.5);

                reflectColor = GetVanillaSkyLux(reflectDir) * reflectF;
            #endif
        }

        #if defined RSM_ENABLED && defined RENDER_DEFERRED
            vec2 viewSize = vec2(viewWidth, viewHeight);

            #if RSM_SCALE == 0 || defined RSM_UPSCALE
                ivec2 iuv = ivec2(texcoord * viewSize);
                vec3 rsmColor = texelFetch(BUFFER_RSM_COLOR, iuv, 0).rgb;
            #else
                const float rsm_scale = 1.0 / exp2(RSM_SCALE);
                vec3 rsmColor = textureLod(BUFFER_RSM_COLOR, texcoord * rsm_scale, 0).rgb;
            #endif
        #endif

        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
            vec3 blockLightAmbient = pow2(blockLight)*blockLightColor;
        #else
            vec3 blockLightAmbient = pow(blockLight, 5.0)*blockLightColor;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
            vec3 specularTint = GetHCM_Tint(material.albedo.rgb, material.hcm);
        #else
            vec3 specularTint = mix(vec3(1.0), material.albedo.rgb, material.f0);
        #endif

        vec3 ambient = vec3(20.0 + blockLightAmbient);
        vec3 diffuse = vec3(0.0);
        vec3 specular = vec3(0.0);
        vec4 final = material.albedo;

        vec3 specFmax = vec3(0.0);
        #ifdef SHADOW_ENABLED
            //float iblFavg = 0.0;
            #if REFLECTION_MODE != REFLECTION_MODE_NONE
                // IBL
                vec3 iblF = GetFresnel(material, NoVm, roughL);
                vec2 envBRDF = texture(BUFFER_BRDF_LUT, vec2(NoVm, material.smoothness)).rg;
                envBRDF = RGBToLinear(vec3(envBRDF, 0.0)).rg;

                vec3 iblSpec = skyLight5 * reflectColor * specularTint * (iblF * envBRDF.x + envBRDF.y) * material.occlusion;
                specular += max(iblSpec, vec3(0.0));

                //return vec4(envBRDF * 500.0, 0.0, 1.0);

                float iblFavg = clamp((iblF.x + iblF.y + iblF.z) / 3.0, 0.0, 1.0);
                final.a = min(final.a + iblFavg, 1.0);

                specFmax = max(specFmax, iblF);
            #endif

            float NoHm = max(dot(viewNormal, halfDir), EPSILON);
            float VoHm = max(dot(viewDir, halfDir), EPSILON);

            vec3 F = GetFresnel(material, VoHm, roughL);
            vec3 sunSpec = GetSpecularBRDF(F, NoVm, NoLm, NoHm, roughL) * specularTint * skyLightColor * shadowFinal;
            specular += sunSpec;

            final.a = min(final.a + luminance(sunSpec) * exposure, 1.0);

            specFmax = max(specFmax, F);
        #endif

        #ifdef SHADOW_ENABLED
            vec3 skyAmbient = GetSkyAmbientLight(viewNormal) * skyLight5; //skyLightColor;
            ambient += skyAmbient;

            vec3 diffuseLight = skyLightColor * shadowFinal;

            #if defined RSM_ENABLED && defined RENDER_DEFERRED
                diffuseLight += 20.0 * rsmColor * skyLightColor * material.scattering;
            #endif

            vec3 sunDiffuse = GetDiffuseBSDF(material, NoVm, NoLm, LoHm, roughL) * diffuseLight;
            diffuse += (1.0 - specFmax) * sunDiffuse;
            //diffuse += sunDiffuse;
        #endif

        #ifdef HANDLIGHT_ENABLED
            if (heldBlockLightValue > EPSILON)
                ApplyHandLighting(diffuse, specular, material, viewNormal, viewPos.xyz, viewDir, NoVm, roughL);
        #endif

        #if defined RSM_ENABLED && defined RENDER_DEFERRED
            ambient += rsmColor * skyLightColor;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
            if (material.hcm >= 0) {
                //if (material.hcm < 8) specular *= material.albedo.rgb;

                diffuse *= HCM_AMBIENT;
                ambient *= HCM_AMBIENT;

                // #if REFLECTION_MODE == REFLECTION_MODE_NONE
                //     diffuse *= HCM_AMBIENT;
                //     ambient *= 0.02;
                // #else
                //     diffuse = vec3(0.0);
                //     ambient *= 0.02;
                // #endif
            }
        #else
            float metalDarkF = 1.0 - material.f0 * (1.0 - HCM_AMBIENT);
            diffuse *= metalDarkF;
            ambient *= metalDarkF;
        #endif

        //ambient += minLight;

        float emissive = material.emission*material.emission * EmissionLumens;

        final.rgb = final.rgb * (ambient * material.occlusion + emissive) + diffuse + specular;

        #ifdef SSS_ENABLED
            //float ambientShadowBrightness = 1.0 - 0.5 * (1.0 - SHADOW_BRIGHTNESS);
            vec3 ambient_sss = 4.0 * skyAmbient * material.scattering * material.occlusion;

            // Transmission
            vec3 sss = (1.0 - shadowFinal) * shadowSSS * material.scattering * skyLightColor;// * max(-NoL, 0.0);
            final.rgb += material.albedo.rgb * invPI * (ambient_sss + sss);
        #endif

        #ifdef VL_ENABLED
            mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
            vec4 shadowViewStart = matViewToShadowView * vec4(vec3(0.0), 1.0);
            vec4 shadowViewEnd = matViewToShadowView * vec4(viewPos, 1.0);

            shadowViewStart.xyz /= shadowViewStart.w;
            shadowViewEnd.xyz /= shadowViewEnd.w;

            float volLight = GetVolumtricLighting(shadowViewStart.xyz, shadowViewEnd.xyz);
            //final.rgb += 0.5 * volLight;
            final.rgb += volLight * skyLightColor;
        #endif

        #if defined RENDER_DEFERRED
            ApplyFog(final.rgb, viewPos.xyz, skyLight);
        #elif defined RENDER_GBUFFER
            #ifdef RENDER_WATER
                ApplyFog(final, viewPos.xyz, skyLight, EPSILON);
            #else
                ApplyFog(final, viewPos.xyz, skyLight, alphaTestRef);
            #endif
        #endif

        //return vec4(material.normal * 100.0, 1.0);
        return final;
    }
#endif
