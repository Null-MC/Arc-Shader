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

    float SmithHable(const in float LdotH, const in float alpha)
    {
        return 1.0 / mix(LdotH * LdotH, 1.0, alpha * alpha * 0.25);
    }

    vec3 GetSpecularBRDF(const in PbrMaterial material, const in float LoH, const in float NoH, const in float VoH, const in float roughL)
    {
        // Fresnel
        vec3 F;
        if (material.hcm >= 0) {
            vec3 iorN, iorK;
            GetHCM_IOR(material.albedo.rgb, material.hcm, iorN, iorK);
            F = F_conductor(VoH, IOR_AIR, iorN, iorK);
        }
        else {
            F = vec3(SchlickRoughness(material.f0, VoH, roughL));
        }

        // Distribution
        float D = GGX(NoH, roughL);

        // Geometric Visibility
        float G = SmithHable(LoH, roughL);

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
        const vec3 handLightColor = vec3(0.851, 0.712, 0.545);

        float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
            float diffuseAtt = max(0.16*lightLevel - 0.5*lightDist, 0.0);
            return diffuseAtt*diffuseAtt;
        }

        void ApplyHandLighting(inout vec3 diffuse, inout vec3 specular, const in PbrMaterial material, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL) {
            vec3 handLightPos = handOffset - viewPos.xyz;
            vec3 handLightDir = normalize(handLightPos);

            float hand_NoLm = max(dot(viewNormal, handLightDir), EPSILON);

            if (hand_NoLm > EPSILON) {
                float handLightDist = length(handLightPos);
                vec3 handHalfDir = normalize(handLightDir + viewDir);
                float hand_LoHm = max(dot(handLightDir, handHalfDir), EPSILON);

                float attenuation = GetHandLightAttenuation(heldBlockLightValue, handLightDist);

                if (attenuation > EPSILON) {
                    float hand_NoHm = max(dot(viewNormal, handHalfDir), EPSILON);
                    float hand_VoHm = max(dot(viewDir, handHalfDir), EPSILON);

                    diffuse += GetDiffuseBSDF(material, NoVm, hand_NoLm, hand_LoHm, roughL) * attenuation * handLightColor;
                    specular += GetSpecularBRDF(material, hand_LoHm, hand_NoHm, hand_VoHm, roughL) * attenuation * handLightColor;
                }
            }
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

        float blockLight = (lmValue.x - (0.5/16.0)) / (15.0/16.0);
        float skyLight = (lmValue.y - (0.5/16.0)) / (15.0/16.0);

        blockLight = blockLight*blockLight*blockLight;
        skyLight = skyLight*skyLight*skyLight;

        // Increase skylight when in direct sunlight
        skyLight = max(skyLight, shadow);

        // Make areas without skylight fully shadowed (light leak fix)
        float lightLeakFix = step(1.0 / 32.0, skyLight);
        float shadowFinal = shadow * lightLeakFix;

        vec3 reflectColor = vec3(0.0);
        #ifdef SSR_ENABLED
            vec3 reflectDir = reflect(viewDir, viewNormal);
            vec2 reflectCoord = GetReflectCoord(reflectDir);

            ivec2 iTexReflect = ivec2(reflectCoord * vec2(viewWidth, viewHeight));
            reflectColor = texelFetch(colortex8, iTexReflect, 0);
        #endif

        vec3 skyAmbient = GetSkyAmbientColor(viewNormal) * (0.1 + 0.9 * skyLight); //skyLightColor;

        vec3 blockAmbient = max(vec3(blockLight), skyAmbient * SHADOW_BRIGHTNESS);

        vec3 ambient = blockAmbient * material.occlusion;

        vec3 diffuse = GetDiffuseBSDF(material, NoVm, NoLm, LoHm, roughL) * skyLightColor * shadowFinal;

        vec3 specular = vec3(0.0);

        #ifdef SHADOW_ENABLED
            float NoHm = max(dot(viewNormal, halfDir), EPSILON);
            float VoHm = max(dot(viewDir, halfDir), EPSILON);

            specular = GetSpecularBRDF(material, LoHm, NoHm, VoHm, roughL) * skyLightColor * shadowFinal;
        #endif

        #ifdef HANDLIGHT_ENABLED
            if (heldBlockLightValue > EPSILON)
                ApplyHandLighting(diffuse, specular, material, viewNormal, viewPos.xyz, viewDir, NoVm, roughL);
        #endif

        if (material.hcm >= 0) {
            if (material.hcm < 8) specular *= material.albedo.rgb;

            ambient *= HCM_AMBIENT;
            diffuse *= HCM_AMBIENT;
        }

        ambient += minLight;

        #if defined RSM_ENABLED && defined RENDER_DEFERRED
            // TODO: linear sampling
            //vec2 texSize = vec2(viewWidth, viewHeight) * RSM_SCALE;
            //vec3 rsmColor = FetchLinearRGB(colortex5, texcoord * texSize - 1.0) * skyLightColor;

            ivec2 iuv = ivec2(texcoord * vec2(viewWidth, viewHeight));
            vec3 rsmColor = texelFetch(colortex7, iuv, 0).rgb;
            //rsmColor = RGBToLinear(rsmColor);
            //ambient = max(ambient, rsmColor * skyLightColor);
            ambient += rsmColor * skyLightColor;
        #endif

        float emissive = material.emission * 16.0;

        vec4 final = material.albedo;
        final.rgb = final.rgb * (ambient + emissive) + diffuse + specular;

        #ifdef SSS_ENABLED
            //float ambientShadowBrightness = 1.0 - 0.5 * (1.0 - SHADOW_BRIGHTNESS);
            //vec3 ambient_sss = vec3(0.0);//ambientShadowBrightness * skyAmbient * material.scattering * material.occlusion;

            //float lightSSS = lightingMap.a;
            vec3 sss = (1.0 - shadowFinal) * shadowSSS * material.scattering * skyLightColor;// * max(-NoL, 0.0);

            //lit += ambient_sss + sss;
            final.rgb += 1.25 * material.albedo.rgb * invPI * sss;
        #endif

        #ifdef SHADOW_ENABLED
            if (final.a < 1.0 - EPSILON) {
                //float F = SchlickRoughness(0.04, VoHm, roughL);
                float F = F_schlick(NoVm, material.f0, 1.0);
                final.a = mix(final.a, 1.0, F);
            }
        #endif

        final.a += luminance(specular);

        #ifndef RENDER_DEFERRED
            #if defined RENDER_WATER
                ApplyFog(final, viewPos.xyz, skyLight, EPSILON);
            #else
                ApplyFog(final, viewPos.xyz, skyLight, alphaTestRef);
            #endif
        #endif

        //return mix(final, reflectColor, 0.5);
        return final;
    }
#endif
