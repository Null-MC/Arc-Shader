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

            if (materialId == MATERIAL_WATER) {
                //material.albedo = vec4(1.0, 0.0, 0.0, 1.0);
                material.smoothness = WATER_SMOOTH;
                material.f0 = 0.02;
            }
        }
    #endif

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
            lightData.skyLightLevels = skyLightLevels;
            lightData.sunTransmittance = GetSunTransmittance(colortex9, worldPos.y, skyLightLevels.x);
            lightData.moonTransmittance = GetMoonTransmittance(colortex9, worldPos.y, skyLightLevels.y);
            lightData.sunTransmittanceEye = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);
            lightData.moonTransmittanceEye = GetMoonTransmittance(colortex9, eyeAltitude, skyLightLevels.y);
        #endif

        #if defined PARALLAX_ENABLED || WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
            vec3 tanViewDir = normalize(tanViewPos);
        #endif

        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        float viewDist = length(viewPos) - near;
        vec3 viewDir = normalize(viewPos);

        #if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
            gl_FragDepth = gl_FragCoord.z;
        #endif

        #if defined RENDER_WATER && defined WATER_FANCY && defined WATER_ENABLED
            if (materialId == MATERIAL_WATER) {
                material.albedo = WATER_COLOR;
                material.normal = vec3(0.0, 0.0, 1.0);
                material.occlusion = 1.0;
                material.smoothness = WATER_SMOOTH;
                material.scattering = 0.0;
                material.f0 = 0.02;
                material.hcm = -1;

                const float waterPixelSize = rcp(WATER_RESOLUTION);

                #if WATER_WAVE_TYPE != WATER_WAVE_NONE
                    #ifndef PHYSICS_OCEAN
                        const float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                        vec3 waterWorldPos = waterScale * worldPos;

                        float waveDepth = GetWaveDepth(lightData.skyLight);

                        int octaves = WATER_OCTAVES_FAR;
                        #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                            //float viewDist = length(viewPos) - near;
                            float octaveDistF = saturate(viewDist / WATER_OCTAVES_DIST);
                            octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, octaveDistF));
                        #endif

                        float depth = GetWaves(waterWorldPos.xz, waveDepth, octaves);
                        depth *= waveDepth * WaterWaveDepthF;

                        vec3 waterPos = waterWorldPos.xzy;
                        waterPos.z = depth * WATER_NORMAL_STRENGTH;

                        #ifdef MC_GL_VENDOR_AMD
                            vec3 waterDX = vec3(dFdx(waterPos.x), dFdx(waterPos.y), dFdx(waterPos.z));
                            vec3 waterDY = vec3(dFdy(waterPos.x), dFdy(waterPos.y), dFdy(waterPos.z));
                        #else
                            vec3 waterDX = dFdx(waterPos);
                            vec3 waterDY = dFdy(waterPos);
                        #endif
                    #endif
                #endif

                #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
                    const float waterWorldScale = rcp(2.0*WATER_RADIUS);
                    vec2 waterLocalPos = localPos.xz * waterWorldScale;

                    const float texBoundary = 0.5 - waterPixelSize;
                    if (clamp(waterLocalPos, vec2(-texBoundary), vec2(texBoundary)) == waterLocalPos) {
                        vec3 waterTex = vec3(waterLocalPos + 0.5, 1.0);
                        mat2 water_dFdXY = mat2(dFdx(waterLocalPos), dFdy(waterLocalPos));

                        if (viewDist < WATER_RADIUS && tanViewDir.z < 0.0) {
                            float waterDepth = max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepth, 0.0);
                            GetWaterParallaxCoord(waterTex, water_dFdXY, tanViewDir, viewDist, waterDepth, lightData.skyLight);

                            //const float waterParallaxDepth = WaterWaveDepthF / (2.0*WATER_RADIUS);
                            float pomDist = isEyeInWater == 1 ? waterTex.z : (1.0 - waterTex.z);
                            pomDist /= max(-tanViewDir.z, 0.01);
                            pomDist *= waveDepth;

                            if (pomDist > 0.0) {
                                // vec3 viewDir = normalize(viewPosFinal);
                                vec3 newViewPosFinal = viewPosFinal + viewDir * pomDist;// * waterParallaxDepth;
                                float fragDepth = 0.5 * ((-gbufferProjection[2].z*-newViewPosFinal.z + gbufferProjection[3].z) / -newViewPosFinal.z) + 0.5;

                                #if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
                                    viewPosFinal = newViewPosFinal;
                                    gl_FragDepth = fragDepth;
                                #endif

                                //float depth = viewPos.z - pomDist * waterParallaxDepth;
                                lightData.transparentScreenDepth = fragDepth;
                                lightData.transparentScreenDepthLinear = linearizeDepthFast(fragDepth, near, far);
                            }
                        }

                        float depth = textureGrad(BUFFER_WATER_WAVES, waterTex.xy, water_dFdXY[0], water_dFdXY[1]).r;
                        float depthX = textureGradOffset(BUFFER_WATER_WAVES, waterTex.xy, water_dFdXY[0], water_dFdXY[1], ivec2(1, 0)).r;
                        float depthY = textureGradOffset(BUFFER_WATER_WAVES, waterTex.xy, water_dFdXY[0], water_dFdXY[1], ivec2(0, 1)).r;

                        float dx = depthX - depth;
                        float dy = depthY - depth;

                        float waterParallaxDepth = 8.0 * (waveDepth / (2.0*WATER_RADIUS));

                        material.normal = normalize(cross(
                          vec3(waterPixelSize, 0.0, dx * waterParallaxDepth * WATER_NORMAL_STRENGTH),
                          vec3(0.0, waterPixelSize, dy * waterParallaxDepth * WATER_NORMAL_STRENGTH)));
                    }
                    else {
                #endif

                #if WATER_WAVE_TYPE != WATER_WAVE_NONE
                    #ifdef PHYSICS_OCEAN
                        float waveScaledIterations = 1.0 - saturate((length(localPos) - 16.0) / 200.0);
                        float waveIterations = max(12.0, physics_iterationsNormal * (waveScaledIterations * 0.6 + 0.4));

                        float waviness = textureLod(physics_waviness, physics_localPosition.xz / vec2(textureSize(physics_waviness, 0)), 0).r;
                        waviness += 0.02 * lightData.skyLight;

                        material.normal = physics_waveNormal(physics_localPosition.xz, waviness, physics_gameTime, waveIterations);
                        material.normal = mat3(gl_ModelViewMatrix) * material.normal;
                    #else
                        vec3 viewUp = normalize(upPosition);
                        if (isEyeInWater == 1) viewUp = -viewUp;

                        if (dot(viewNormal, viewUp) > EPSILON) {
                            // int octaves = WATER_OCTAVES_FAR;
                            // #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                            //     //float viewDist = length(viewPos) - near;
                            //     octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, saturate(viewDist / 200.0)));
                            // #endif

                            //float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
                            //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                            //float waveStrength = GetWaveDepth(windSpeed, skyLight);

                            //float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                            //vec2 waterWorldPos = waterScale * (localPos.xz + cameraPosition.xz);

                            //depth = GetWaves(waterWorldPos, waveDepth, octaves) * waveDepth * WATER_NORMAL_STRENGTH;
                            //waterPos = vec3(waterWorldPos.x, waterWorldPos.y, depth);

                            material.normal = normalize(cross(waterDX, waterDY));

                            if (isEyeInWater != 1)
                                material.normal = -material.normal;
                        }
                        //else {
                        //    material.normal = viewNormal;
                        //}
                    #endif
                #endif

                #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
                    }
                #endif
            }
            else {
        #endif

            #ifdef PARALLAX_ENABLED
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

                #if defined PARALLAX_ENABLED && defined PARALLAX_SMOOTH_NORMALS
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
                #else
                    // TODO: Is this helping or hurting performance doing discard on transparent?
                    if (material.albedo.a < 1.5/255.0) discard;
                #endif

                //#if MATERIAL_FORMAT != MATERIAL_FORMAT_LABPBR
                    if (materialId == MATERIAL_WATER) {
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

                #if defined PARALLAX_ENABLED && defined PARALLAX_SLOPE_NORMALS
                    float dO = max(texDepth - traceCoordDepth.z, 0.0);
                    if (dO >= 0.95 / 255.0 && materialId != MATERIAL_WATER) {
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

        #if defined RENDER_WATER && defined WATER_FANCY && defined WATER_ENABLED
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
        
        if (materialId != MATERIAL_WATER) {
            #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
                ApplyDirectionalLightmap(lightData.blockLight, material.normal);
            #endif

            if (isEyeInWater == 1) {
                material.albedo.rgb = WetnessDarkenSurface(material.albedo.rgb, material.porosity, 1.0);
            }

            #if defined SKY_ENABLED && !defined RENDER_HAND_WATER && (WETNESS_MODE != WEATHER_MODE_NONE || SNOW_MODE != WEATHER_MODE_NONE)
                if (isEyeInWater != 1) {
                    vec3 tanUpDir = normalize(upPosition) * matTBN;
                    float NoU = dot(material.normal, tanUpDir);

                    ApplyWeather(material, NoU, viewDist, lightData.blockLight, lightData.skyLight);
                }
            #endif
        }

        if (!gl_FrontFacing)
            material.normal = -material.normal;

        #if defined RENDER_WATER && defined PHYSICS_OCEAN
            if (materialId != MATERIAL_WATER)
                material.normal = matTBN * material.normal;
        #else
            material.normal = matTBN * material.normal;
        #endif

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #ifdef SHADOW_DITHER
                float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                for (int i = 0; i < 4; i++) {
                    lightData.shadowPos[i] = shadowPos[i];
                    lightData.shadowBias[i] = shadowBias[i];
                    lightData.shadowTilePos[i] = GetShadowCascadeClipPos(i);

                    lightData.matShadowProjection[i] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                    
                    #ifdef SHADOW_DITHER
                        lightData.shadowPos[i].xy += ditherOffset;
                    #endif
                }

                lightData.opaqueShadowDepth = GetNearestOpaqueDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.opaqueShadowCascade);
                lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.transparentShadowCascade);

                float minTransparentDepth = min(lightData.shadowPos[lightData.transparentShadowCascade].z, lightData.transparentShadowDepth);
                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * 3.0 * far;
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                lightData.shadowPos = shadowPos;
                lightData.shadowBias = shadowBias;

                #ifdef SHADOW_DITHER
                    lightData.shadowPos.xy += ditherOffset;
                #endif

                lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos, vec2(0.0));

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    const float maxShadowDepth = 512.0;
                #else
                    const float maxShadowDepth = 256.0;
                #endif

                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * maxShadowDepth;
            #endif
        #endif

        vec4 finalColor = PbrLighting2(material, lightData, viewPosFinal);

        if (isEyeInWater != 1) {
            #if !(defined SKY_ENABLED && ATMOSPHERE_TYPE == ATMOSPHERE_FANCY)
                vec3 fogColorFinal;
                float fogFactorFinal;
                GetFog(lightData, viewPos, fogColorFinal, fogFactorFinal);
            #endif

            #ifdef SKY_ENABLED
                vec2 scatteringF = GetVanillaSkyScattering(viewDir, skyLightLevels);

                #if !defined VL_SKY_ENABLED && ATMOSPHERE_TYPE == ATMOSPHERE_VANILLA
                    vec3 sunColorFinalEye = lightData.sunTransmittanceEye * sunColor * max(lightData.skyLightLevels.x, 0.0);
                    vec3 moonColorFinalEye = lightData.moonTransmittanceEye * moonColor * max(lightData.skyLightLevels.y, 0.0) * GetMoonPhaseLevel();

                    fogColorFinal += RGBToLinear(fogColor) * (
                        scatteringF.x * sunColorFinalEye +
                        scatteringF.y * moonColorFinalEye);
                #endif
            #endif

            #if !(defined SKY_ENABLED && ATMOSPHERE_TYPE == ATMOSPHERE_FANCY)
                ApplyFog(finalColor, fogColorFinal, fogFactorFinal, 1.0/255.0);
            #endif

            #ifdef SKY_ENABLED
                vec3 localViewDir = normalize(localPos);

                float cloudDepthTest = CLOUD_LEVEL - (cameraPosition.y + localPos.y);
                cloudDepthTest *= sign(CLOUD_LEVEL - cameraPosition.y);

                if (cloudDepthTest < 0.0) {
                    float cloudF = GetCloudFactor(cameraPosition, localViewDir, 0);

                    float cloudHorizonFogF = 1.0 - abs(localViewDir.y);
                    cloudF *= 1.0 - pow(cloudHorizonFogF, 8.0);

                    vec3 sunDir = GetSunDir();
                    float sun_VoL = dot(viewDir, sunDir);

                    vec3 moonDir = GetMoonDir();
                    float moon_VoL = dot(viewDir, moonDir);

                    vec3 cloudColor = GetCloudColor(skyLightLevels, sun_VoL, moon_VoL);

                    cloudF = smoothstep(0.0, 1.0, cloudF);
                    finalColor.rgb = mix(finalColor.rgb, cloudColor, cloudF);
                    // TODO: mix opacity?
                }

                #if defined VL_SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    vec3 viewNear = viewDir * near;
                    vec3 viewFar = viewDir * min(length(viewPos), far);
                    vec3 vlExt = vec3(1.0);

                    vec3 vlColor = GetVolumetricLighting(lightData, vlExt, viewNear, viewFar, scatteringF);

                    finalColor.rgb = finalColor.rgb * vlExt + vlColor;

                    // TODO: increase alpha with VL?
                #endif
            #endif
        }

        return finalColor;
    }
#endif
