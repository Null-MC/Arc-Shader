#ifdef RENDER_VERTEX
#endif

#ifdef RENDER_FRAG
    const vec3 minLight = vec3(0.01);
    const float lmPadding = 1.0 / 32.0;

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

        blockLight *= blockLight;
        skyLight *= skyLight;

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

        //vec3 lmValue = vec3(1.0);
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

        vec3 _viewNormal = normalize(viewNormal);
        vec3 viewDir = -normalize(viewPos); // vec3(0.0, 0.0, 1.0);

        #ifdef SHADOW_ENABLED
            vec3 viewLightDir = normalize(shadowLightPosition);
            //float NoL = max(dot(_viewNormal, viewLightDir), 0.0);

            vec3 viewHalfDir = normalize(viewLightDir + viewDir);
            float LoH = max(dot(viewLightDir, viewHalfDir), 0.0);
        #else
            //float NoL = 1.0;
            float LoH = 1.0;
        #endif

        float NoV = max(dot(_viewNormal, viewDir), 0.0);

        float rough = 1.0 - material.smoothness;
        float roughL = rough * rough;

        vec3 ambient = material.albedo.rgb * max(blockLight, 0.3 * skyLight) * material.occlusion;

        vec3 diffuse = material.albedo.rgb * Diffuse_Burley(NoL, NoV, LoH, roughL) * lightColor;

        #ifdef SHADOW_ENABLED
            float NoH = max(dot(_viewNormal, viewHalfDir), 0.0);
            float VoH = max(dot(viewDir, viewHalfDir), 0.0);

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

        vec4 final;
        final.rgb = ambient + diffuse + specular + emissive;
        final.a = material.albedo.a + luminance(specular);

        #ifdef RENDER_WATER
            ApplyFog(final, viewPos, EPSILON);
        #else
            ApplyFog(final, viewPos, alphaTestRef);
        #endif

        return final;
    }
#endif
