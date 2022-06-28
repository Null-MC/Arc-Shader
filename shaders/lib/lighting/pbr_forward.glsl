#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 PbrLighting() {
        vec2 atlasCoord = texcoord;

        #ifdef PARALLAX_ENABLED
            float texDepth = 1.0;
            vec3 traceCoordDepth = vec3(1.0);
            vec3 tanViewDir = normalize(tanViewPos);

            #ifndef PARALLAX_USE_TEXELFETCH
                mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
            #endif

            if (viewPos.z < PARALLAX_DISTANCE) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    atlasCoord = GetParallaxCoord(tanViewDir, texDepth, traceCoordDepth);
                #else
                    atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, texDepth, traceCoordDepth);
                #endif
            }
        #endif

        PbrMaterial material;
        PopulateMaterial(atlasCoord, material);

        bool isWater = false;
        #ifndef RENDER_WATER
            if (material.albedo.a < alphaTestRef) discard;
        #else
            if (materialId == 1) {
                isWater = true;
                //material.albedo = vec4(0.2, 0.4, 0.8, 1.0);
                material.f0 = 0.02;
                material.smoothness = 0.96;
                material.normal = vec3(0.0, 0.0, 1.0);
            }
        #endif

        #ifdef PARALLAX_SLOPE_NORMALS
            if (!isWater) {
                float dO = max(texDepth - traceCoordDepth.z, 0.0);
                if (dO >= 0.95 / 255.0) {
                    #ifdef PARALLAX_USE_TEXELFETCH
                        material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                    #else
                        material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                    #endif
                }
            }
        #endif
        
        float blockLight = (lmcoord.x - (0.5/16.0)) / (15.0/16.0);
        float skyLight = (lmcoord.y - (0.5/16.0)) / (15.0/16.0);

        blockLight = blockLight*blockLight*blockLight;
        skyLight = skyLight*skyLight*skyLight;

        float shadow = step(EPSILON, geoNoL) * step(1.0 / 32.0, skyLight);
        vec3 lightColor = skyLightColor;
        float NoL = 1.0;

        #ifdef SHADOW_ENABLED
            vec3 tanLightDir = normalize(tanLightPos);
            NoL = dot(material.normal, tanLightDir);
            shadow *= step(EPSILON, NoL);

            #ifdef PARALLAX_SHADOWS_ENABLED
                if (shadow > EPSILON && traceCoordDepth.z + EPSILON < 1.0) {
                    #ifdef PARALLAX_USE_TEXELFETCH
                        shadow *= GetParallaxShadow(traceCoordDepth, tanLightDir);
                    #else
                        shadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);
                    #endif
                }
            #endif
        #endif

        if (shadow > EPSILON) {
            #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
                shadow *= GetShadowing(shadowPos);

                #if SHADOW_COLORS == 1
                    vec3 shadowColor = GetShadowColor();

                    shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    // make colors less intense when the block light level is high.
                    shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    lightColor *= shadowColor;
                #endif

                skyLight = max(skyLight, shadow);
            #endif
        }

        float lightSSS = 0.0;
        #ifdef SSS_ENABLED
            if (material.scattering > EPSILON) {
                lightSSS = GetShadowSSS(shadowPos);
            }
        #endif

        vec3 _viewNormal = normalize(viewNormal);
        vec3 viewDir = -normalize(viewPos);

        //lightColor *= shadow;

        #ifdef SHADOW_ENABLED
            vec3 viewLightDir = normalize(shadowLightPosition);
            vec3 viewHalfDir = normalize(viewLightDir + viewDir);
            float LoH = max(dot(viewLightDir, viewHalfDir), 0.0);
        #else
            float LoH = 1.0;
        #endif

        float NoV = max(dot(_viewNormal, viewDir), 0.0);

        float rough = 1.0 - material.smoothness;
        float roughL = rough * rough;

        vec3 ambient = material.albedo.rgb * max(blockLight, SHADOW_BRIGHTNESS * skyLight) * material.occlusion;

        vec3 diffuse = GetDiffuse_Burley(material.albedo.rgb, NoV, NoL, LoH, roughL) * lightColor * shadow;

        vec3 specular = vec3(0.0);

        #ifdef SHADOW_ENABLED
            float NoH = max(dot(_viewNormal, viewHalfDir), 0.0);
            float VoH = max(dot(viewDir, viewHalfDir), 0.0);

            specular = GetSpecularBRDF(material, LoH, NoH, VoH, roughL) * NoL * lightColor * shadow*shadow;
        #endif

        if (heldBlockLightValue > 0) {
            vec3 handLightPos = handOffset - viewPos;
            vec3 handLightDir = normalize(handLightPos);
            float hand_NoL = max(dot(_viewNormal, handLightDir), 0.0);

            if (hand_NoL > EPSILON) {
                float lightDist = length(handLightPos);
                float handLightDiffuseAtt = max(0.16*heldBlockLightValue - 0.5*lightDist, 0.0);
                vec3 hand_halfDir = normalize(handLightDir + viewDir);
                float hand_LoH = max(dot(handLightDir, hand_halfDir), 0.0);

                if (handLightDiffuseAtt > EPSILON) {
                    diffuse += GetDiffuse_Burley(material.albedo.rgb, NoV, hand_NoL, hand_LoH, roughL) * handLightDiffuseAtt*handLightDiffuseAtt;
                }

                float handLightSpecularAtt = max(0.16*heldBlockLightValue - 0.25*lightDist, 0.0);

                if (handLightSpecularAtt > EPSILON) {
                    float hand_NoH = max(dot(_viewNormal, hand_halfDir), 0.0);
                    float hand_VoH = max(dot(viewDir, hand_halfDir), 0.0);
                    specular += GetSpecularBRDF(material, hand_LoH, hand_NoH, hand_VoH, roughL) * hand_NoL * handLightSpecularAtt;
                }
            }
        }

        if (material.hcm >= 0) {
            if (material.hcm < 8) specular *= material.albedo.rgb;

            ambient *= HCM_AMBIENT;
            diffuse *= HCM_AMBIENT;
        }

        ambient += material.albedo.rgb * minLight;

        vec3 emissive = material.albedo.rgb * material.emission * 16.0;

        vec3 sss = 0.2 * material.albedo.rgb * material.scattering * lightSSS * lightColor;

        vec4 final;
        final.rgb = ambient + diffuse + specular + emissive + sss;
        final.a = material.albedo.a + luminance(specular);

        #ifdef RENDER_WATER
            ApplyFog(final, viewPos, skyLight, EPSILON);
        #else
            ApplyFog(final, viewPos, skyLight, alphaTestRef);
        #endif

        return final;
    }
#endif
