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
            material.emission = matEmissive;
        }
    #endif

    vec4 PbrLighting() {
        vec3 traceCoordDepth = vec3(1.0);
        //vec2 waterSolidDepth = vec2(0.0);
        vec2 atlasCoord = texcoord;
        float texDepth = 1.0;
        PbrMaterial material;

        PbrLightData lightData;
        lightData.blockLight = lmcoord.x;
        lightData.skyLight = lmcoord.y;
        lightData.geoNoL = geoNoL;
        lightData.occlusion = 1.0;

        #if AO_TYPE == AO_TYPE_FAST
            lightData.occlusion = pow2(glcolor.a);
        #endif

        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));

        #ifdef PARALLAX_ENABLED
            vec3 tanViewDir = normalize(tanViewPos);
        #endif

        #ifdef RENDER_WATER
            if (materialId == 1) {
                vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
                vec2 waterSolidDepth = GetWaterSolidDepth(screenUV);
                lightData.waterShadowDepth = waterSolidDepth.x;
                lightData.solidShadowDepth = waterSolidDepth.y;
            }
        #endif

        #if defined RENDER_WATER && defined WATER_FANCY && !defined WORLD_NETHER
            if (materialId == 1) {
                material.albedo = vec4(vec3(0.0178, 0.0566, 0.0754), 0.06);
                //material.albedo = vec4(vec3(0.6, 0.0, 0.0), 0.0);
                material.normal = vec3(0.0, 0.0, 1.0);
                material.occlusion = 1.0;
                material.smoothness = WATER_SMOOTH;
                material.scattering = 0.0;
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
                            //float waterDepth = max(waterSolidDepth.y - waterSolidDepth.x, 0.0);
                            float waterDepth = max(lightData.solidShadowDepth - lightData.waterShadowDepth, 0.0);
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

                    float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));

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

        vec3 _viewNormal = normalize(viewNormal);
        vec3 _viewTangent = normalize(viewTangent);
        vec3 _viewBinormal = normalize(cross(_viewTangent, _viewNormal) * tangentW);
        mat3 matTBN = mat3(_viewTangent, _viewBinormal, _viewNormal);
        
        material.normal = matTBN * material.normal;

        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
            ApplyDirectionalLightmap(lightData.blockLight, material.normal);
        #endif

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0))).xyz;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                for (int i = 0; i < 4; i++) {
                    lightData.matShadowProjection[i] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                    lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    
                    vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                    lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + shadowCascadePos;
                }
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                lightData.shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz);
                #endif

                lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;
            #endif
        #endif

        return PbrLighting2(material, lightData, viewPos.xyz);
    }
#endif
