#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 PbrLighting() {
        vec3 traceCoordDepth = vec3(1.0);
        //vec2 waterSolidDepth = vec2(0.0);
        vec3 viewPosFinal = viewPos;
        vec2 atlasCoord = texcoord;
        float texDepth = 1.0;
        PbrMaterial material;

        vec3 worldPos = localPos + cameraPosition;

        LightData lightData;
        lightData.occlusion = 1.0;
        lightData.blockLight = saturate(lmcoord.x);
        lightData.skyLight = saturate(lmcoord.y);
        lightData.geoNoL = saturate(geoNoL);
        lightData.parallaxShadow = 1.0;

        lightData.transparentScreenDepth = gl_FragCoord.z;
        lightData.opaqueScreenDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
        lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);
        lightData.transparentScreenDepthLinear = linearizeDepthFast(lightData.transparentScreenDepth, near, far);

        #if AO_TYPE == AO_TYPE_VANILLA
            lightData.occlusion = pow2(glcolor.a);
        #endif

        #ifdef SKY_ENABLED
            float eyeElevation = GetScaledSkyHeight(cameraPosition.y);
            float fragElevation = GetAtmosphereElevation(worldPos);

            #ifdef IS_IRIS
                lightData.sunTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.x);
            #else
                lightData.sunTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.x);
            #endif

            #ifdef WORLD_MOON_ENABLED
                #ifdef IS_IRIS
                    lightData.moonTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.y);
                #else
                    lightData.moonTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.y);
                #endif
            #endif
        #endif

        #if defined PARALLAX_ENABLED && !defined RENDER_TEXTURED
            vec3 tanViewDir = normalize(tanViewPos);
        #endif

        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        float viewDist = length(viewPos) - near;
        vec3 viewDir = normalize(viewPos);

        #if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
            gl_FragDepth = gl_FragCoord.z;
        #endif

        #if defined WORLD_WATER_ENABLED && defined RENDER_WATER
            if (materialId == BLOCK_WATER) {
                material.albedo = vec4(waterFoamColor, 0.0);
                material.normal = vec3(0.0, 0.0, 1.0);
                material.occlusion = 1.0;
                material.scattering = 0.9;
                material.smoothness = WATER_SMOOTH;
                material.f0 = 0.02;
                material.hcm = -1;

                vec2 waterUV = worldPos.xz;
                float waveAmplitude = 0.0;

                vec3 viewUp = normalize(upPosition);
                if (isEyeInWater == 1) viewUp = -viewUp;

                #if defined WATER_WAVE_ENABLED || defined PHYSICS_OCEAN
                    #ifdef PHYSICS_OCEAN
                        WavePixelData waveData = physics_wavePixel(physics_localPosition, physics_localWaviness, physics_iterationsNormal, physics_gameTime);
                        vec3 waveNormal = physics_waveNormal(waveData, physics_localWaviness);

                        #ifdef WATER_FOAM_ENABLED
                            waveAmplitude = waveData.height * pow(max(waveNormal.y, 0.0), 4.0);
                            waterUV = waveData.worldPos;
                        #endif

                        material.normal = mat3(gl_ModelViewMatrix) * waveNormal;
                    #else
                        const float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                        vec3 waterWorldPos = waterScale * worldPos;

                        float waveDepth = GetWaveDepth(lightData.skyLight);

                        int octaves = WATER_OCTAVES_FAR;
                        //float viewDist = length(viewPos) - near;
                        float octaveDistF = saturate(viewDist / WATER_OCTAVES_DIST);
                        octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, octaveDistF));

                        vec3 waves = GetWaves(waterWorldPos.xz, waveDepth, octaves);
                        //float depth = GetWaves(waterWorldPos.xz, waveDepth, octaves);

                        vec3 waterPos = waterWorldPos.xzy;
                        waterPos.z = (waves.y * waveDepth * WaterWaveDepthF) * WATER_NORMAL_STRENGTH;

                        //#ifdef MC_GL_VENDOR_AMD
                        //    vec3 waterDX = vec3(dFdx(waterPos.x), dFdx(waterPos.y), dFdx(waterPos.z));
                        //    vec3 waterDY = vec3(dFdy(waterPos.x), dFdy(waterPos.y), dFdy(waterPos.z));
                        //#else
                            vec3 waterDX = dFdx(waterPos);
                            vec3 waterDY = dFdy(waterPos);
                        //#endif

                        if (dot(viewNormal, viewUp) > EPSILON) {
                            material.normal = normalize(cross(waterDX, waterDY));

                            if (isEyeInWater != 1)
                                material.normal = -material.normal;
                        }

                        waterUV = waves.xz / waterScale;
                        waveAmplitude = 4.0 * (waves.y - 0.2) * pow(max(material.normal.y, 0.0), 1.0);
                    #endif
                #endif

                #ifdef WATER_FOAM_ENABLED
                    if (dot(viewNormal, viewUp) > EPSILON) {
                        material.albedo.rgb = RGBToLinear(material.albedo.rgb);

                        float time = frameTimeCounter / 360.0;
                        vec2 s1 = textureLod(TEX_CLOUD_NOISE, vec3(waterUV * 0.30, time      ), 0).rg;
                        vec2 s2 = textureLod(TEX_CLOUD_NOISE, vec3(waterUV * 0.02, time + 0.5), 0).rg;

                        float waterSurfaceNoise = s1.r * s2.r * 1.5;

                        float waterEdge = max(0.8 - 2.0 * max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0), 0.0);
                        waterSurfaceNoise += pow2(waterEdge);

                        waveAmplitude = saturate(waveAmplitude * 1.2);
                        //waveAmplitude = smoothstep(0.0, 0.8, waveAmplitude);
                        waterSurfaceNoise = (1.0 - waveAmplitude) * waterSurfaceNoise + waveAmplitude;

                        float worleyNoise = 0.2 + 0.8 * s1.g * (1.0 - s2.g);
                        waterSurfaceNoise = smoothstep(waterFoamMinSmooth, 1.0, waterSurfaceNoise) * worleyNoise;

                        material.albedo.a = saturate(waterFoamMaxSmooth * waterSurfaceNoise);
                        material.smoothness = mix(WATER_SMOOTH, 1.0 - waterRoughSmooth, waterSurfaceNoise);
                    }
                #endif
            }
            else {
        #endif

            #if defined PARALLAX_ENABLED && !defined RENDER_TEXTURED
                // bool skipParallax =
                //     viewDist >= PARALLAX_DISTANCE ||
                //     materialId == 101 ||
                //     materialId == 111;

                if (viewDist < PARALLAX_DISTANCE) {
                    atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);

                    #if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
                        float pomDist = (1.0 - traceCoordDepth.z) / max(-tanViewDir.z, 0.00001);

                        if (pomDist > 0.0) {
                            float pomDepth = length(viewPos) + pomDist * PARALLAX_DEPTH;
                            gl_FragDepth = 0.5 * (-gbufferProjection[2].z*pomDepth + gbufferProjection[3].z) / pomDepth + 0.5;
                        }
                    #endif
                }
            #endif

            vec4 colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]);
            colorMap.rgb *= glcolor.rgb;

            #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
                vec4 specularMap = textureGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);
                vec3 normalMap;

                #if defined PARALLAX_ENABLED && defined MATERIAL_SMOOTH_NORMALS
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

                //#if !(defined RENDER_WATER || defined RENDER_HAND_WATER || defined RENDER_ENTITIES_TRANSLUCENT)
                //    if (material.albedo.a < 0.1) discard;
                //#else
                    // TODO: Is this helping or hurting performance doing discard on transparent?
                    if (material.albedo.a < 1.5/255.0) discard;
                //#endif

                //#if MATERIAL_FORMAT != MATERIAL_FORMAT_LABPBR
                    if (materialId == BLOCK_WATER) {
                        //material.albedo = vec4(1.0, 0.0, 0.0, 1.0);
                        material.f0 = 0.02;
                        material.smoothness = WATER_SMOOTH;// += 0.96 * step(material.smoothness, EPSILON);

                        // #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
                        //     material.smoothness = 0.96;
                        //     material.normal = vec3(0.0, 0.0, 1.0);
                        //     material.occlusion = 1.0;
                        //     material.albedo.a = 0.06;
                        // #endif
                    }
                //#endif

                #if defined PARALLAX_ENABLED && !defined RENDER_TEXTURED && PARALLAX_SHAPE == PARALLAX_SHAPE_SHARP
                    float dO = max(texDepth - traceCoordDepth.z, 0.0);
                    if (dO >= 0.95 / 255.0 && materialId != BLOCK_WATER) {
                        //#ifdef PARALLAX_USE_TEXELFETCH
                        //    material.normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                        //#else
                            material.normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                        //#endif
                    }
                #endif
            #else
                material.albedo.rgb = RGBToLinear(colorMap.rgb);
                material.albedo.a = colorMap.a;

                // TODO: Is this helping or hurting performance doing discard on transparent?
                if (material.albedo.a < 1.5/255.0) discard;

                #ifdef RENDER_TEXTURED
                    // TODO
                #else
                    #ifdef RENDER_ENTITIES
                        ApplyHardCodedMaterials(material, entityId);
                    #else
                        ApplyHardCodedMaterials(material, materialId, worldPos);
                    #endif
                #endif
            #endif

        #if defined WORLD_WATER_ENABLED && defined RENDER_WATER
            }
        #endif

        // #if DEBUG_VIEW == DEBUG_VIEW_WHITEWORLD
        //     material.albedo.rgb = vec3(1.0);
        // #endif

        vec3 _viewNormal = normalize(viewNormal);

        // if (!gl_FrontFacing) {
        //     _viewNormal = -_viewNormal;
        // }

        vec3 _viewTangent = normalize(viewTangent);
        vec3 _viewBinormal = normalize(cross(_viewTangent, _viewNormal) * tangentW);

        // if (!gl_FrontFacing) {
        //     _viewTangent = -_viewTangent;
        //     _viewBinormal = -_viewBinormal;
        // }

        mat3 matTBN = mat3(_viewTangent, _viewBinormal, _viewNormal);
        
        #if !(defined RENDER_HAND || defined RENDER_TEXTURED)
            if (materialId != BLOCK_WATER) {
                #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0 && !(defined RENDER_ENTITIES || defined RENDER_TEXTURED)
                    ApplyDirectionalLightmap(lightData.blockLight, viewPos, viewNormal, material.normal);
                #endif

                #if defined SKY_ENABLED && (WETNESS_MODE != WEATHER_MODE_NONE || SNOW_MODE != WEATHER_MODE_NONE) && !(defined RENDER_HAND_WATER || defined RENDER_ENTITIES)
                    if (isEyeInWater != 1) {
                        vec3 tanUpDir = normalize(upPosition) * matTBN;
                        float NoU = dot(material.normal, tanUpDir);

                        ApplyWeather(material, NoU, viewDist, lightData.blockLight, lightData.skyLight);
                    }
                #endif
            }
        #endif

        if (!gl_FrontFacing)
            material.normal = -material.normal;

        #if defined RENDER_WATER && defined PHYSICS_OCEAN
            if (materialId != BLOCK_WATER)
                material.normal = matTBN * material.normal;
        #else
            material.normal = matTBN * material.normal;
        #endif

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                lightData.shadowPos[0] = shadowPos[0];
                lightData.shadowPos[1] = shadowPos[1];
                lightData.shadowPos[2] = shadowPos[2];
                lightData.shadowPos[3] = shadowPos[3];

                lightData.shadowBias[0] = shadowBias[0];
                lightData.shadowBias[1] = shadowBias[1];
                lightData.shadowBias[2] = shadowBias[2];
                lightData.shadowBias[3] = shadowBias[3];

                lightData.shadowCascade = GetShadowSampleCascade(shadowPos, shadowPcfSize);
                SetNearestDepths(lightData);

                float minTransparentDepth = min(lightData.shadowPos[lightData.shadowCascade].z, lightData.transparentShadowDepth);
                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * (3.0 * far);
            #else
                lightData.shadowPos = shadowPos;
                lightData.shadowBias = shadowBias;

                vec2 shadowPosD = distort(shadowPos.xy * 2.0 - 1.0) * 0.5 + 0.5;

                lightData.opaqueShadowDepth = SampleOpaqueDepth(shadowPosD, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(shadowPosD, vec2(0.0));

                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * (far * 2.0);
            #endif
        #endif

        vec4 finalColor = PbrLighting2(material, lightData, viewPosFinal);

        #ifdef SKY_ENABLED
            if (isEyeInWater != 1) {
                vec3 localViewDir = normalize(localPos);

                float cloudDepthTest = SKY_CLOUD_LEVEL - (cameraPosition.y + localPos.y);
                cloudDepthTest *= sign(SKY_CLOUD_LEVEL - cameraPosition.y);

                if (HasClouds(cameraPosition, localViewDir) && cloudDepthTest < 0.0) {
                    vec3 cloudPos = GetCloudPosition(cameraPosition, localViewDir);
                    float cloudF = GetCloudFactor(cloudPos, localViewDir, 0);
                    cloudF = smoothstep(0.0, 0.6, cloudF);

                    cloudF *= 1.0 - blindness;
                    vec3 cloudColor = GetCloudColor(cloudPos, localViewDir, skyLightLevels);

                    #if !(defined SKY_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE)
                        vec3 localSunDir = GetSunLocalDir();
                        vec3 localLightDir = GetShadowLightLocalDir();
                        float VoL = dot(localLightDir, localViewDir);
                        vec4 scatteringTransmittance = GetFancyFog(cloudPos - cameraPosition, localSunDir, VoL);
                        cloudColor = cloudColor * scatteringTransmittance.a + scatteringTransmittance.rgb;
                    #endif
                    
                    finalColor.rgb = mix(finalColor.rgb, cloudColor, cloudF);
                }

                #if defined SKY_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    vec3 vlScatter, vlExt;
                    GetVolumetricLighting(vlScatter, vlExt, localViewDir, near, min(viewDist, far));
                    finalColor.rgb = finalColor.rgb * vlExt + vlScatter;

                    // TODO: increase alpha with VL?
                #endif
            }
        #endif

        return finalColor;
    }
#endif
