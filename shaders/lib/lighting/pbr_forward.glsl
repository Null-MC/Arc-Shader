#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 PbrLighting() {
        vec2 atlasCoord = texcoord;
        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));

        #ifdef PARALLAX_ENABLED
            float texDepth = 1.0;
            vec3 traceCoordDepth = vec3(1.0);
            vec3 tanViewDir = normalize(tanViewPos);

            float viewDist = length(viewPos);
            if (viewDist < PARALLAX_DISTANCE) {
                atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);
            }
        #endif

        vec4 colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]) * glcolor;
        vec4 specularMap = textureGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);
        vec3 normalMap;// = textureGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]);

        #ifdef PARALLAX_SMOOTH_NORMALS
            ////normalMap.rgb = TexelFetchLinearRGB(normals, atlasCoord * atlasSize);
            //normalMap.rgb = TextureGradLinearRGB(normals, atlasCoord, atlasSize, dFdXY);

            vec2 uv[4];
            //vec2 localCoord = GetLocalCoord(atlasCoord);
            //vec2 atlasTileSize = atlasBounds[1] * atlasSize;
            vec2 f = GetLinearCoords(atlasCoord, atlasSize, uv);

            uv[0] = GetAtlasCoord(GetLocalCoord(uv[0]));
            uv[1] = GetAtlasCoord(GetLocalCoord(uv[1]));
            uv[2] = GetAtlasCoord(GetLocalCoord(uv[2]));
            uv[3] = GetAtlasCoord(GetLocalCoord(uv[3]));

            ivec2 iuv[4];
            iuv[0] = ivec2(uv[0] * atlasSize);
            iuv[1] = ivec2(uv[1] * atlasSize);
            iuv[2] = ivec2(uv[2] * atlasSize);
            iuv[3] = ivec2(uv[3] * atlasSize);

            //normalMap.rgb = TextureGradLinearRGB(normals, uv, dFdXY, f);
            normalMap = TexelFetchLinearRGB(normals, iuv, 0, f);
        #else
            normalMap = textureGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).rgb;
        #endif

        PbrMaterial material;
        PopulateMaterial(material, colorMap, normalMap, specularMap);

        bool isWater = false;
        #ifndef RENDER_WATER
            if (material.albedo.a < alphaTestRef) discard;
        #else
            if (materialId == 1) {
                isWater = true;
                material.f0 = 0.02;
                material.smoothness = 0.96;
                material.normal = vec3(0.0, 0.0, 1.0);
                material.occlusion = 1.0;
                material.albedo.a = 0.06;
            }
        #endif

        #ifdef PARALLAX_SLOPE_NORMALS
            float dO = max(texDepth - traceCoordDepth.z, 0.0);
            if (dO >= 0.95 / 255.0 && !isWater) {
                //#ifdef PARALLAX_USE_TEXELFETCH
                //    material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                //#else
                    material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                //#endif
            }
        #endif
        
        float shadow = step(EPSILON, geoNoL);// * step(1.0 / 32.0, skyLight);
        float NoL = 1.0;

        #ifdef SHADOW_ENABLED
            vec3 tanLightDir = normalize(tanLightPos);
            NoL = dot(material.normal, tanLightDir);
            shadow *= step(EPSILON, NoL);

            #ifdef PARALLAX_SHADOWS_ENABLED
                if (shadow > EPSILON && traceCoordDepth.z + EPSILON < 1.0)
                    shadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);
            #endif
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
            if (shadow > EPSILON) {
                shadow *= GetShadowing(shadowPos);

                // #if SHADOW_COLORS == 1
                //     vec3 shadowColor = GetShadowColor();

                //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                //     // make colors less intense when the block light level is high.
                //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                //     lightColor *= shadowColor;
                // #endif

                //skyLight = max(skyLight, shadow);
            }
        #endif

        float shadowSSS = 0.0;
        #ifdef SSS_ENABLED
            if (material.scattering > EPSILON) {
                shadowSSS = GetShadowSSS(shadowPos);
            }
        #endif

        material.normal = material.normal * matTBN;

        vec2 lm = lmcoord;
        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
            ApplyDirectionalLightmap(lm.x, material.normal);
        #endif

        //lm = vec2(0.0);

        return PbrLighting2(material, lm, shadow, shadowSSS, viewPos.xyz);
    }
#endif
