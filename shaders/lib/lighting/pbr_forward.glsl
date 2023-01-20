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

            #if SHADER_PLATFORM == PLATFORM_IRIS
                lightData.sunTransmittance = GetSunTransmittance(texSunTransmittance, worldPos.y, skyLightLevels.x);
                lightData.moonTransmittance = GetMoonTransmittance(texSunTransmittance, worldPos.y, skyLightLevels.y);
                lightData.sunTransmittanceEye = GetSunTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.x);
                lightData.moonTransmittanceEye = GetMoonTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.y);
            #else
                lightData.sunTransmittance = GetSunTransmittance(colortex12, worldPos.y, skyLightLevels.x);
                lightData.moonTransmittance = GetMoonTransmittance(colortex12, worldPos.y, skyLightLevels.y);
                lightData.sunTransmittanceEye = GetSunTransmittance(colortex12, eyeAltitude, skyLightLevels.x);
                lightData.moonTransmittanceEye = GetMoonTransmittance(colortex12, eyeAltitude, skyLightLevels.y);
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
                        //float viewDist = length(viewPos) - near;
                        float octaveDistF = saturate(viewDist / WATER_OCTAVES_DIST);
                        octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, octaveDistF));

                        float depth = GetWaves(waterWorldPos.xz, waveDepth, octaves);
                        depth *= waveDepth * WaterWaveDepthF;

                        vec3 waterPos = waterWorldPos.xzy;
                        waterPos.z = depth * WATER_NORMAL_STRENGTH;

                        //#ifdef MC_GL_VENDOR_AMD
                        //    vec3 waterDX = vec3(dFdx(waterPos.x), dFdx(waterPos.y), dFdx(waterPos.z));
                        //    vec3 waterDY = vec3(dFdy(waterPos.x), dFdy(waterPos.y), dFdy(waterPos.z));
                        //#else
                            vec3 waterDX = dFdx(waterPos);
                            vec3 waterDY = dFdy(waterPos);
                        //#endif
                    #endif
                #endif

                #if WATER_WAVE_TYPE != WATER_WAVE_NONE || defined PHYSICS_OCEAN
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
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                lightData.shadowPos[0] = shadowPos[0];
                lightData.shadowPos[1] = shadowPos[1];
                lightData.shadowPos[2] = shadowPos[2];
                lightData.shadowPos[3] = shadowPos[3];

                lightData.opaqueShadowDepth = GetNearestOpaqueDepth(lightData.shadowPos, vec2(0.0), lightData.shadowCascade);
                lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData.shadowPos, vec2(0.0), lightData.shadowCascade);

                float minTransparentDepth = min(lightData.shadowPos[lightData.shadowCascade].z, lightData.transparentShadowDepth);
                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * 3.0 * far;
            #else
                lightData.shadowPos = shadowPos;
                lightData.shadowBias = shadowBias;

                lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos.xy, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos.xy, vec2(0.0));

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    const float maxShadowDepth = 512.0;
                #else
                    const float maxShadowDepth = 256.0;
                #endif

                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * maxShadowDepth;
            #endif
        #endif

        vec4 finalColor = PbrLighting2(material, lightData, viewPosFinal);

        #ifdef SKY_ENABLED
            if (isEyeInWater != 1) {
                vec3 localViewDir = normalize(localPos);

                float cloudDepthTest = CLOUD_LEVEL - (cameraPosition.y + localPos.y);
                cloudDepthTest *= sign(CLOUD_LEVEL - cameraPosition.y);

                if (HasClouds(cameraPosition, localViewDir) && cloudDepthTest < 0.0) {
                    vec3 cloudPos = GetCloudPosition(cameraPosition, localViewDir);
                    float cloudF = GetCloudFactor(cloudPos, localViewDir, 0);

                    float cloudHorizonFogF = 1.0 - abs(localViewDir.y);
                    cloudF *= 1.0 - pow(cloudHorizonFogF, 8.0);

                    // vec3 sunDir = GetSunDir();
                    // float sun_VoL = dot(viewDir, sunDir);

                    // vec3 moonDir = GetMoonDir();
                    // float moon_VoL = dot(viewDir, moonDir);

                    vec3 cloudColor = GetCloudColor(cloudPos, viewDir, skyLightLevels);

                    //cloudF = smoothstep(0.0, 1.0, cloudF);
                    finalColor.rgb = mix(finalColor.rgb, cloudColor, cloudF);
                    // TODO: mix opacity?
                }

                #if defined VL_SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    vec3 viewNear = viewDir * near;
                    vec3 viewFar = viewDir * min(viewDist, far);
                    vec3 vlExt = vec3(1.0);

                    vec2 skyScatteringF = GetVanillaSkyScattering(viewDir, skyLightLevels);
                    vec3 vlColor = GetVolumetricLighting(lightData, vlExt, viewNear, viewFar, skyScatteringF);

                    finalColor.rgb = finalColor.rgb * vlExt + vlColor;

                    // TODO: increase alpha with VL?
                #endif
            }
        #endif

        return finalColor;
    }
#endif
