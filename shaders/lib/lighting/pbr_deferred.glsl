//#define ALLOW_TEXELFETCH

#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec3 PbrLighting() {
        #ifdef ALLOW_TEXELFETCH
            ivec2 iTex = ivec2(texcoord * vec2(viewWidth, viewHeight));
            vec3 colorMap = texelFetch(colortex0, iTex, 0).rgb;
            float screenDepth = texelFetch(depthtex0, iTex, 0).r;
        #else
            vec3 colorMap = texture2DLod(colortex0, texcoord, 0).rgb;
            float screenDepth = texture2DLod(depthtex0, texcoord, 0).r;
        #endif

        // SKY
        if (screenDepth == 1.0) return colorMap;

        #ifdef ALLOW_TEXELFETCH
            vec4 normalMap = texelFetch(colortex1, iTex, 0);
            vec4 specularMap = texelFetch(colortex2, iTex, 0);
            vec4 lightingMap = texelFetch(colortex3, iTex, 0);
        #else
            vec4 normalMap = texture2DLod(colortex1, texcoord, 0);
            vec4 specularMap = texture2DLod(colortex2, texcoord, 0);
            vec4 lightingMap = texture2DLod(colortex3, texcoord, 0);
        #endif

        vec3 clipPos = vec3(texcoord, screenDepth) * 2.0 - 1.0;
        vec4 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0));
        viewPos.xyz /= viewPos.w;

        float shadow = lightingMap.b;
        vec3 lightColor = skyLightColor;

        PbrMaterial material = PopulateMaterial(colorMap, normalMap, specularMap);

        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = -normalize(viewPos.xyz);

        #ifdef SHADOW_ENABLED
            vec3 viewLightDir = normalize(shadowLightPosition);
            float NoL = dot(viewNormal, viewLightDir);

            vec3 halfDir = normalize(viewLightDir + viewDir);
            float LoH = max(dot(viewLightDir, halfDir), 0.0);
        #else
            float NoL = 1.0;
            float LoH = 1.0;
        #endif

        float NoLm = max(NoL, 0.0);
        float NoV = max(dot(viewNormal, viewDir), 0.0);

        float rough = 1.0 - material.smoothness;
        float roughL = rough * rough;

        float blockLight = (lightingMap.x - (0.5/16.0)) / (15.0/16.0);
        float skyLight = (lightingMap.y - (0.5/16.0)) / (15.0/16.0);

        blockLight = blockLight*blockLight*blockLight;
        skyLight = skyLight*skyLight*skyLight;

        vec3 reflectColor = vec3(0.0);
        #ifdef SSR_ENABLED
            vec3 reflectDir = reflect(viewDir, viewNormal);
            vec2 reflectCoord = GetReflectCoord(reflectDir);

            #ifdef ALLOW_TEXELFETCH
                ivec2 iTexReflect = ivec2(reflectCoord * vec2(viewWidth, viewHeight));
                reflectColor = texelFetch(colortex4, iTexReflect, 0);
            #else
                reflectColor = texture2DLod(colortex4, reflectCoord, 0);
            #endif
        #endif

        vec3 skyAmbient = SHADOW_BRIGHTNESS * GetSkyAmbientColor(viewNormal) * (0.1 + 0.9 * skyLight); //lightColor;

        vec3 blockAmbient = max(vec3(blockLight), skyAmbient);

        vec3 ambient = blockAmbient * material.occlusion;

        vec3 diffuse = Diffuse_Burley(NoLm, NoV, LoH, roughL) * NoLm * lightColor * shadow;

        vec3 specular = vec3(0.0);

        #ifdef SHADOW_ENABLED
            float NoH = max(dot(viewNormal, halfDir), 0.0);
            float VoH = max(dot(viewDir, halfDir), 0.0);

            specular = GetSpecular(material, LoH, NoH, VoH, roughL) * NoLm * lightColor * shadow*shadow;
        #endif

        if (heldBlockLightValue > 0) {
            const vec3 handLightColor = vec3(0.851, 0.712, 0.545);

            vec3 handLightPos = handOffset - viewPos.xyz;
            vec3 handLightDir = normalize(handLightPos);
            float hand_NoL = max(dot(viewNormal, handLightDir), 0.0);

            if (hand_NoL > EPSILON) {
                float lightDist = length(handLightPos);
                float handLightDiffuseAtt = max(0.16*heldBlockLightValue - 0.5*lightDist, 0.0);
                vec3 hand_halfDir = normalize(handLightDir + viewDir);
                float hand_LoH = max(dot(handLightDir, hand_halfDir), 0.0);

                if (handLightDiffuseAtt > EPSILON) {
                    diffuse += Diffuse_Burley(hand_NoL, NoV, hand_LoH, roughL) * handLightColor * hand_NoL * handLightDiffuseAtt;//*handLightDiffuseAtt;
                }

                float handLightSpecularAtt = max(0.1*heldBlockLightValue - 0.18*lightDist, 0.0);

                if (handLightSpecularAtt > EPSILON) {
                    float hand_NoH = max(dot(viewNormal, hand_halfDir), 0.0);
                    float hand_VoH = max(dot(viewDir, hand_halfDir), 0.0);
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
            ApplyFog(final, viewPos.xyz, skyLight);
        #endif

        //return mix(final, reflectColor, 0.5);

        return ApplyTonemap(final);
    }
#endif
