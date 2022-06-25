#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec3 PbrLighting() {
        vec3 colorMap = texture2DLod(colortex0, texcoord, 0).rgb;
        float screenDepth = texture2DLod(depthtex0, texcoord, 0).r;

        if (screenDepth == 1.0) // SKY
            return RGBToLinear(colorMap);

        vec4 normalMap = texture2DLod(colortex1, texcoord, 0);
        vec4 specularMap = texture2DLod(colortex2, texcoord, 0);
        vec4 lightingMap = texture2DLod(colortex3, texcoord, 0);

        //return lightingMap.rgb;

        vec3 clipPos = vec3(texcoord, screenDepth) * 2.0 - 1.0;
        vec4 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0));
        viewPos.xyz /= viewPos.w;

        float shadow = lightingMap.b;
        vec3 lightColor = skyLightColor;

        PbrMaterial material = PopulateMaterial(colorMap, normalMap, specularMap);
        vec3 worldNormal = normalize(material.normal);

        vec3 localPos = (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0)).xyz;
        vec3 localViewDir = -normalize(localPos);

        #ifdef SHADOW_ENABLED
            vec3 worldLightDir = normalize(worldLightPos);
            float NoL = dot(worldNormal, worldLightDir);

            vec3 halfDir = normalize(worldLightDir + localViewDir);
            float LoH = max(dot(worldLightDir, halfDir), 0.0);
        #else
            float NoL = 1.0;
            float LoH = 1.0;
        #endif

        float NoLm = max(NoL, 0.0);
        float NoV = max(dot(worldNormal, localViewDir), 0.0);

        float rough = 1.0 - material.smoothness;
        float roughL = rough * rough;

        float blockLight = (lightingMap.x - (0.5/16.0)) / (15.0/16.0);
        float skyLight = (lightingMap.y - (0.5/16.0)) / (15.0/16.0);

        blockLight = blockLight*blockLight*blockLight;
        skyLight = skyLight*skyLight*skyLight;

        vec3 skyAmbient = SHADOW_BRIGHTNESS * skyLight * lightColor;

        vec3 blockAmbient = max(vec3(blockLight), skyAmbient);

        vec3 ambient = blockAmbient * material.occlusion;

        vec3 diffuse = Diffuse_Burley(NoLm, NoV, LoH, roughL) * NoLm * lightColor * shadow;

        vec3 specular = vec3(0.0);

        #ifdef SHADOW_ENABLED
            float NoH = max(dot(worldNormal, halfDir), 0.0);
            float VoH = max(dot(localViewDir, halfDir), 0.0);

            specular = GetSpecular(material, LoH, NoH, VoH, roughL) * NoLm * lightColor * shadow*shadow;
        #endif

        if (heldBlockLightValue > 0) {
            const vec3 handLightColor = vec3(0.851, 0.712, 0.545);
            //const vec3 handLightColor = vec3(0.1, 1.0, 0.1);

            vec3 handLightPos = (gbufferModelViewInverse * vec4(handOffset, 1.0)).xyz;
            //handLightPos -= gbufferModelViewInverse[3].xyz;

            vec3 handLightOffset = handLightPos - localPos;
            vec3 handLightDir = normalize(handLightOffset);
            float hand_NoL = max(dot(worldNormal, handLightDir), 0.0);

            if (hand_NoL > EPSILON) {
                float lightDist = length(handLightOffset);
                float handLightDiffuseAtt = max(0.16*heldBlockLightValue - 0.5*lightDist, 0.0);
                vec3 hand_halfDir = normalize(handLightDir + localViewDir);
                float hand_LoH = max(dot(handLightDir, hand_halfDir), 0.0);

                if (handLightDiffuseAtt > EPSILON) {
                    diffuse += Diffuse_Burley(hand_NoL, NoV, hand_LoH, roughL) * handLightColor * hand_NoL * handLightDiffuseAtt;//*handLightDiffuseAtt;
                }

                float handLightSpecularAtt = max(0.1*heldBlockLightValue - 0.18*lightDist, 0.0);

                if (handLightSpecularAtt > EPSILON) {
                    float hand_NoH = max(dot(worldNormal, hand_halfDir), 0.0);
                    float hand_VoH = max(dot(localViewDir, hand_halfDir), 0.0);
                    specular += GetSpecular(material, hand_LoH, hand_NoH, hand_VoH, roughL) * handLightColor * hand_NoL * handLightSpecularAtt;
                }
            }
        }

        if (material.hcm >= 0) {
            if (material.hcm < 8) specular *= material.albedo.rgb;

            ambient *= HCM_AMBIENT;
            diffuse *= HCM_AMBIENT;
        }

        ambient += minLight;

        float emissive = material.emission * 16.0;

        vec3 lit = ambient + diffuse + emissive;

        #ifdef SSS_ENABLED
            vec3 ambient_sss = skyAmbient * material.scattering * material.occlusion;

            //float lightSSS = lightingMap.a;
            vec3 sss = material.scattering * lightingMap.a * lightColor * max(-NoL, 0.0);

            lit += ambient_sss + sss;
        #endif

        vec3 final = material.albedo.rgb * lit + specular;

        #ifdef IS_OPTIFINE
            // Iris doesn't currently support fog in deferred
            ApplyFog(final, viewPos.xyz);
        #endif

        return final;
    }
#endif
