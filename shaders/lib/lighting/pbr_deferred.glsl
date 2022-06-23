#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    const vec3 minLight = vec3(0.01);
    //const float lmPadding = 1.0 / 32.0;

    vec3 PbrLighting() {
        vec3 colorMap = texture2DLod(colortex0, texcoord, 0).rgb;
        float screenDepth = texture2DLod(depthtex0, texcoord, 0).r;

        if (screenDepth + EPSILON >= 1.0) discard; // SKY

        vec4 normalMap = texture2DLod(colortex1, texcoord, 0);
        vec4 specularMap = texture2DLod(colortex2, texcoord, 0);
        vec4 lightingMap = texture2DLod(colortex3, texcoord, 0);

        vec3 clipPos = vec3(texcoord, screenDepth) * 2.0 - 1.0;
        vec4 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0));
        viewPos.xyz /= viewPos.w;

        //float shadow = lightingMap.z;
        vec3 lightColor = skyLightColor * lightingMap.z;

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

        //blockLight *= blockLight;
        //skyLight *= skyLight;

        //vec3 worldViewDir = -normalize(viewPos.xyz);
        float NoV = max(dot(worldNormal, localViewDir), 0.0);

        //vec2 ambientLMCoord = vec2(blockLight, skyLight) * (15.0/16.0) + (0.5/16.0);
        //vec3 ambientLM = RGBToLinear(texture2D(lightmap, lightingMap.xy).rgb);

        // vec2 lmSkyCoord = vec2(0.0, skyLight * (15.0/16.0)) + (0.5/16.0);
        // vec3 lightSky = RGBToLinear(texture2D(lightmap, lmSkyCoord).rgb);

        //vec3 ambient = minLight + 0.3 * ambientLM * material.occlusion;

        float rough = 1.0 - material.smoothness;
        float roughL = rough * rough;

        vec3 ambient = material.albedo.rgb * max(blockLight, 0.3 * skyLight) * material.occlusion;

        vec3 diffuse = material.albedo.rgb * Diffuse_Burley(NoL, NoV, LoH, roughL) * lightColor;

        #ifdef SHADOW_ENABLED
            float NoH = max(dot(worldNormal, halfDir), 0.0);
            float VoH = max(dot(localViewDir, halfDir), 0.0);

            vec3 specular;
            if (material.hcm >= 0) {
                vec3 iorN, iorK;
                GetHCM_IOR(material.albedo.rgb, material.hcm, iorN, iorK);
                specular = SpecularConductor_BRDF(iorN, iorK, LoH, NoH, VoH, roughL) * lightColor;

                if (material.hcm < 8)
                    specular *= material.albedo.rgb;

                ambient *= 0.2;
                diffuse *= 0.2;
            }
            else {
                specular = Specular_BRDF(material.f0, LoH, NoH, VoH, roughL) * lightColor;
            }
        #else
            vec3 specular = vec3(0.0);
        #endif

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
