#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    const vec3 minLight = vec3(0.01);
    const vec3 handOffset = vec3(0.4, -0.3, -0.2);
    //const float lmPadding = 1.0 / 32.0;

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

        float shadow = lightingMap.z;
        vec3 lightColor = skyLightColor * shadow;

        PbrMaterial material = PopulateMaterial(colorMap, normalMap, specularMap);
        vec3 worldNormal = normalize(material.normal);

        vec3 localPos = (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0)).xyz;
        vec3 localViewDir = -normalize(localPos);

        #ifdef SHADOW_ENABLED
            vec3 worldLightDir = normalize(worldLightPos);
            float NoL = max(dot(worldNormal, worldLightDir), 0.0);

            vec3 halfDir = normalize(worldLightDir + localViewDir);
            float LoH = max(dot(worldLightDir, halfDir), 0.0);
        #else
            float NoL = 1.0;
            float LoH = 1.0;
        #endif

        float blockLight = (lightingMap.x - (0.5/16.0)) / (15.0/16.0);
        float skyLight = (lightingMap.y - (0.5/16.0)) / (15.0/16.0);

        blockLight = blockLight*blockLight*blockLight;
        skyLight = skyLight*skyLight*skyLight;

        //vec3 worldViewDir = -normalize(viewPos.xyz);
        float NoV = max(dot(worldNormal, localViewDir), 0.0);

        //vec2 ambientLMCoord = vec2(blockLight, skyLight) * (15.0/16.0) + (0.5/16.0);
        //vec3 ambientLM = RGBToLinear(texture2D(lightmap, lightingMap.xy).rgb);

        // vec2 lmSkyCoord = vec2(0.0, skyLight * (15.0/16.0)) + (0.5/16.0);
        // vec3 lightSky = RGBToLinear(texture2D(lightmap, lmSkyCoord).rgb);

        //vec3 ambient = minLight + 0.3 * ambientLM * material.occlusion;

        float rough = 1.0 - material.smoothness;
        float roughL = rough * rough;

        vec3 ambient = material.albedo.rgb * max(blockLight, SHADOW_BRIGHTNESS * skyLight) * material.occlusion;

        vec3 diffuse = material.albedo.rgb * Diffuse_Burley(NoL, NoV, LoH, roughL) * NoL * lightColor;

        vec3 specular = vec3(0.0);

        #ifdef SHADOW_ENABLED
            float NoH = max(dot(worldNormal, halfDir), 0.0);
            float VoH = max(dot(localViewDir, halfDir), 0.0);

            specular = GetSpecular(material, LoH, NoH, VoH, roughL) * NoL * shadow*shadow;
        #endif

        if (heldBlockLightValue > 0) {
            //vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;
            //vec3 localCameraPosition = (gbufferModelViewInverse * vec4(cameraPosition, 1.0)).xyz;

            //vec3 handLightPos = localPos - cameraPosition;
            //vec3 handLightDir = -normalize(handLightPos);
            //float handLightDist = max(1.0 - 0.02 * length(handLightPos), 0.0);

            vec3 handLightPos = (gbufferModelViewInverse * vec4(handOffset, 1.0)).xyz;
            handLightPos -= gbufferModelViewInverse[3].xyz;

            vec3 handLightOffset = handLightPos - localPos;
            //handLightPos.y -= 0.65;

            vec3 handLightDir = normalize(handLightOffset);
            float hand_NoL = max(dot(worldNormal, handLightDir), 0.0);

            if (hand_NoL > EPSILON) {
                float lightDist = length(handLightOffset);
                //float handLightAtt = max(1.0 - (length(localPos) / (0.6 * heldBlockLightValue)), 0.0);
                float handLightDiffuseAtt = max(0.16*heldBlockLightValue - 0.5*lightDist, 0.0);
                vec3 hand_halfDir = normalize(handLightDir + localViewDir);
                float hand_LoH = max(dot(handLightDir, hand_halfDir), 0.0);

                if (handLightDiffuseAtt > EPSILON) {
                    handLightDiffuseAtt = handLightDiffuseAtt*handLightDiffuseAtt;

                    //vec3 handLightColor = vec3(0.2 * heldBlockLightValue);
                    diffuse += material.albedo.rgb * Diffuse_Burley(hand_NoL, NoV, hand_LoH, roughL) * hand_NoL * handLightDiffuseAtt;
                    //diffuse = material.albedo.rgb * hand_NoL * handLightDiffuseAtt;
                    //diffuse = vec3(LoH);
                }

                float handLightSpecularAtt = max(0.16*heldBlockLightValue - 0.25*lightDist, 0.0) * hand_NoL;

                float hand_NoH = max(dot(worldNormal, hand_halfDir), 0.0);
                float hand_VoH = max(dot(localViewDir, hand_halfDir), 0.0);
                specular += GetSpecular(material, hand_LoH, hand_NoH, hand_VoH, roughL) * handLightSpecularAtt; // * NoL
            }
        }

        if (material.hcm >= 0) {
            if (material.hcm < 8) specular *= material.albedo.rgb;

            ambient *= HCM_AMBIENT;
            diffuse *= HCM_AMBIENT;
        }

        ambient += material.albedo.rgb * minLight;

        vec3 emissive = material.albedo.rgb * material.emission * 16.0;

        vec3 final = ambient + diffuse + specular + emissive;

        #ifdef IS_OPTIFINE
            // Iris doesn't currently support fog in deferred
            ApplyFog(final, viewPos.xyz);
        #endif

        return final;
    }
#endif
