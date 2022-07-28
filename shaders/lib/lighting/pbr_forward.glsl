#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
        void ApplyVanillaProperties(inout PbrMaterial material, const in vec4 colorMap) {
            material.albedo.rgb = RGBToLinear(colorMap.rgb);
            material.albedo.a = colorMap.a;
            material.occlusion = 1.0;
            material.normal = vec3(0.0, 0.0, 1.0);
            material.smoothness = matSmooth;
            material.scattering = matSSS;
            material.f0 = GetLabPbr_F0(matF0);
            material.hcm = GetLabPbr_HCM(matF0);
        }
    #endif

    vec4 PbrLighting() {
        vec3 traceCoordDepth = vec3(1.0);
        vec2 waterSolidDepth = vec2(0.0);
        vec2 atlasCoord = texcoord;
        float texDepth = 1.0;
        vec2 lm = lmcoord;
        PbrMaterial material;

        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        vec3 tanViewDir = normalize(tanViewPos);

        #ifdef RENDER_WATER
            if (materialId == 1) {
                vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
                waterSolidDepth = GetWaterSolidDepth(screenUV);
            }
        #endif

        #if defined RENDER_WATER && defined WATER_FANCY && !defined WORLD_NETHER
            if (materialId == 1) {
                material.albedo = vec4(vec3(0.0178, 0.0566, 0.0754), 0.06);
                material.normal = vec3(0.0, 0.0, 1.0);
                material.occlusion = 1.0;
                material.smoothness = 0.96;
                material.scattering = 0.8;
                material.f0 = 0.02;
                material.hcm = -1;

                const float waterPixelSize = rcp(WATER_RESOLUTION);

                float windSpeed = GetWindSpeed();
                float zScale = 8.0 + windSpeed; // 32

                vec2 waterLocalPos = rcp(2.0*WATER_RADIUS) * localPos.xz;
                float depth, depthX, depthY;

                #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
                    if (
                        waterLocalPos.x > -0.5 && waterLocalPos.x < 0.5 &&
                        waterLocalPos.y > -0.5 && waterLocalPos.y < 0.5
                    ) {
                        float viewDist = length(viewPos);
                        vec2 waterTex = waterLocalPos + 0.5;
                        mat2 water_dFdXY = mat2(dFdx(waterLocalPos), dFdy(waterLocalPos));

                        if (viewDist < WATER_RADIUS) {
                            float waterDepth = max(waterSolidDepth.y - waterSolidDepth.x, 0.0);
                            waterTex = GetWaterParallaxCoord(waterTex, water_dFdXY, tanViewDir, viewDist, waterDepth);

                            // TODO: depth-write
                        }

                        //vec4 depthSamples = textureGather(BUFFER_WATER_WAVES, waterTex, 0);
                        //vec2 f = GetLinearCoords(texcoord, texSize, uv);
                        //depth = LinearBlend4(depthSamples, f);

                        depth = textureGrad(BUFFER_WATER_WAVES, waterTex, water_dFdXY[0], water_dFdXY[1]).r;
                        depthX = textureGradOffset(BUFFER_WATER_WAVES, waterTex, water_dFdXY[0], water_dFdXY[1], ivec2(1, 0)).r;
                        depthY = textureGradOffset(BUFFER_WATER_WAVES, waterTex, water_dFdXY[0], water_dFdXY[1], ivec2(0, 1)).r;
                    }
                    else {
                #endif

                    int octaves = WATER_OCTAVES_FAR;
                    #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                        float viewDist = length(viewPos) - near;
                        octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, saturate(viewDist / 200.0)));
                    #endif

                    float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                    vec2 waterWorldPos = waterScale * (localPos.xz + cameraPosition.xz);
                    vec2 waterWorldPosX = waterWorldPos + vec2(1.0, 0.0)*waterPixelSize;
                    vec2 waterWorldPosY = waterWorldPos + vec2(0.0, 1.0)*waterPixelSize;

                    float skyLight = saturate((lm.y - (0.5/16.0)) / (15.0/16.0));

                    float waveSpeed = GetWaveSpeed(windSpeed, skyLight);

                    depth = GetWaves(waterWorldPos, waveSpeed, octaves);
                    depthX = GetWaves(waterWorldPosX, waveSpeed, octaves);
                    depthY = GetWaves(waterWorldPosY, waveSpeed, octaves);
                    zScale *= WATER_SCALE;

                #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
                    }
                #endif
                
                vec3 pX = vec3(1.0, 0.0, (depthX - depth) * zScale);
                vec3 pY = vec3(0.0, 1.0, (depthY - depth) * zScale);
                
                material.normal = normalize(cross(pX, pY));
            }
            else {
        #endif

            #ifdef PARALLAX_ENABLED
                float viewDist = length(viewPos);
                if (viewDist < PARALLAX_DISTANCE)
                    atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);
            #endif

            vec4 colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]);
            colorMap.rgb *= glcolor.rgb;

            #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
                vec4 specularMap = textureGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);
                vec3 normalMap;

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

                PopulateMaterial(material, colorMap, normalMap, specularMap);

                #if !defined RENDER_WATER && !defined RENDER_HAND_WATER
                    if (material.albedo.a < alphaTestRef) discard;
                #endif

                //#if MATERIAL_FORMAT != MATERIAL_FORMAT_LABPBR
                    if (materialId == 1) {
                        //material.albedo.r = 1.0;
                        material.f0 = 0.02;
                        material.smoothness += 0.96 * step(material.smoothness, EPSILON);

                        // #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
                        //     material.smoothness = 0.96;
                        //     material.normal = vec3(0.0, 0.0, 1.0);
                        //     material.occlusion = 1.0;
                        //     material.albedo.a = 0.06;
                        // #endif
                    }
                //#endif

                #ifdef PARALLAX_SLOPE_NORMALS
                    float dO = max(texDepth - traceCoordDepth.z, 0.0);
                    if (dO >= 0.95 / 255.0 && materialId != 1) {
                        //#ifdef PARALLAX_USE_TEXELFETCH
                        //    material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                        //#else
                            material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                        //#endif
                    }
                #endif
            #else
                ApplyVanillaProperties(material, colorMap);
            #endif

        #if defined RENDER_WATER && defined WATER_FANCY && !defined WORLD_NETHER
            }
        #endif
        
        float shadow = step(EPSILON, geoNoL);// * step(1.0 / 32.0, skyLight);
        vec3 shadowColorMap = vec3(1.0);
        float NoL = 1.0;

        #ifdef SHADOW_ENABLED
            vec3 tanLightDir = normalize(tanLightPos);
            NoL = dot(material.normal, tanLightDir);
            shadow *= step(EPSILON, NoL);

            #ifdef PARALLAX_SHADOWS_ENABLED
                #if defined RENDER_WATER && defined WATER_FANCY
                    if (materialId != 1) {
                #endif

                    if (shadow > EPSILON && traceCoordDepth.z + EPSILON < 1.0)
                        shadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);

                #if defined RENDER_WATER && defined WATER_FANCY
                    }
                #endif
            #endif
        #endif

        float shadowSSS = 0.0;
        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            if (shadow > EPSILON) {
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    shadow *= GetShadowing(shadowPos);
                #else
                    shadow *= GetShadowing(shadowPos, shadowBias);
                #endif
            }

            #ifdef SHADOW_COLOR
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    shadowColorMap = GetShadowColor(shadowPos);
                #else
                    shadowColorMap = GetShadowColor(shadowPos.xyz, shadowBias);
                #endif
                
                shadowColorMap = RGBToLinear(shadowColorMap);
            #endif

            #ifdef SSS_ENABLED
                if (material.scattering > EPSILON) {
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        shadowSSS = GetShadowSSS(shadowPos);
                    #else
                        shadowSSS = GetShadowSSS(shadowPos, shadowBias);
                    #endif
                }
            #endif
        #else
            shadow = glcolor.a;
        #endif

        material.normal = material.normal * matTBN;

        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
            ApplyDirectionalLightmap(lm.x, material.normal);
        #endif

        return PbrLighting2(material, shadowColorMap, lm, shadow, shadowSSS, viewPos.xyz, waterSolidDepth);
    }
#endif
