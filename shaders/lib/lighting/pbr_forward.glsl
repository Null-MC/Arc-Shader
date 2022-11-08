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

            if (materialId == 100 || materialId == 101) {
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

        #ifdef AO_ENABLED
            lightData.occlusion = pow2(glcolor.a);
        #endif

        #ifdef SKY_ENABLED
            float worldY = localPos.y + cameraPosition.y;
            lightData.skyLightLevels = skyLightLevels;
            lightData.sunTransmittance = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);// * sunColor;
            lightData.sunTransmittanceEye = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);// * sunColor;
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

        #if defined RENDER_WATER && defined WATER_FANCY && !defined WORLD_NETHER && !defined WORLD_END
            if (materialId == 100 || materialId == 101) {
                material.albedo = WATER_COLOR;
                material.normal = vec3(0.0, 0.0, 1.0);
                material.occlusion = 1.0;
                material.smoothness = WATER_SMOOTH;
                material.scattering = 0.0;
                material.f0 = 0.02;
                material.hcm = -1;

                const float waterPixelSize = rcp(WATER_RESOLUTION);

                float windSpeed = GetWindSpeed();
                float zScale = 8.0 + windSpeed; // 32

                float depth, depthX, depthY;
                vec3 waterPos;
                
                float waveDepth = GetWaveDepth(lightData.skyLight);

                #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
                    const float waterWorldScale = rcp(2.0*WATER_RADIUS);
                    vec2 waterLocalPos = localPos.xz * waterWorldScale;

                    if (
                        waterLocalPos.x > -0.5 && waterLocalPos.x < 0.5 &&
                        waterLocalPos.y > -0.5 && waterLocalPos.y < 0.5
                    ) {
                        vec3 waterTex = vec3(waterLocalPos + 0.5, 1.0);
                        mat2 water_dFdXY = mat2(dFdx(waterLocalPos), dFdy(waterLocalPos));

                        if (viewDist < WATER_RADIUS && tanViewDir.z < 0.0) {
                            float waterDepth = max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepth, 0.0);
                            GetWaterParallaxCoord(waterTex, water_dFdXY, tanViewDir, viewDist, waterDepth, lightData.skyLight);

                            //const float waterParallaxDepth = WATER_WAVE_DEPTH / (2.0*WATER_RADIUS);
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

                        depth = textureGrad(BUFFER_WATER_WAVES, waterTex.xy, water_dFdXY[0], water_dFdXY[1]).r;
                        float depthX = textureGradOffset(BUFFER_WATER_WAVES, waterTex.xy, water_dFdXY[0], water_dFdXY[1], ivec2(1, 0)).r;
                        float depthY = textureGradOffset(BUFFER_WATER_WAVES, waterTex.xy, water_dFdXY[0], water_dFdXY[1], ivec2(0, 1)).r;

                        float dx = depthX - depth;
                        float dy = depthY - depth;

                        float waterParallaxDepth = 8.0 * (waveDepth / (2.0*WATER_RADIUS));
                        const float waterPixelSize = rcp(WATER_RESOLUTION);

                        material.normal = normalize(cross(
                          vec3(waterPixelSize, 0.0, dx * waterParallaxDepth * WATER_NORMAL_STRENGTH),
                          vec3(0.0, waterPixelSize, dy * waterParallaxDepth * WATER_NORMAL_STRENGTH)));
                    }
                    else {
                #endif

                    vec3 viewUp = normalize(upPosition);
                    if (isEyeInWater == 1) viewUp = -viewUp;
                    if (dot(viewNormal, viewUp) > EPSILON) {
                        int octaves = WATER_OCTAVES_FAR;
                        #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                            //float viewDist = length(viewPos) - near;
                            octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, saturate(viewDist / 200.0)));
                        #endif

                        float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
                        //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                        //float waveStrength = GetWaveDepth(windSpeed, skyLight);

                        float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                        vec2 waterWorldPos = waterScale * (localPos.xz + cameraPosition.xz);

                        depth = GetWaves(waterWorldPos, waveDepth, octaves) * waveDepth * WATER_NORMAL_STRENGTH;
                        waterPos = vec3(waterWorldPos.x, waterWorldPos.y, depth);

                        material.normal = normalize(
                            cross(
                                dFdxFine(waterPos),
                                dFdyFine(waterPos))
                            );

                        if (isEyeInWater != 1)
                            material.normal = -material.normal;
                    }
                    //else {
                    //    material.normal = viewNormal;
                    //}

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
                            float depth = length(viewPos) + pomDist * PARALLAX_DEPTH;
                            gl_FragDepth = 0.5 * (-gbufferProjection[2].z*depth + gbufferProjection[3].z) / depth + 0.5;
                        }
                    #endif
                }
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
                    if (materialId == 100 || materialId == 101) {
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

                #ifdef PARALLAX_SLOPE_NORMALS
                    float dO = max(texDepth - traceCoordDepth.z, 0.0);
                    if (dO >= 0.95 / 255.0 && materialId != 100 && materialId != 101) {
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

        #if defined RENDER_WATER && defined WATER_FANCY && !defined WORLD_NETHER && !defined WORLD_END
            }
        #endif

        #if DEBUG_VIEW == DEBUG_VIEW_WHITEWORLD
            material.albedo.rgb = vec3(1.0);
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
            vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPosFinal, 1.0))).xyz;

            #ifdef SHADOW_DITHER
                float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                for (int i = 0; i < 4; i++) {
                    lightData.matShadowProjection[i] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                    lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    
                    vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                    lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + shadowCascadePos;
                    lightData.shadowTilePos[i] = GetShadowCascadeClipPos(i);
                    lightData.shadowBias[i] = GetCascadeBias(lightData.geoNoL, i);

                    #ifdef SHADOW_DITHER
                        lightData.shadowPos[i].xy += ditherOffset;
                    #endif
                }

                lightData.opaqueShadowDepth = GetNearestOpaqueDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.opaqueShadowCascade);
                lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.transparentShadowCascade);

                //float minOpaqueDepth = min(lightData.shadowPos[lightData.opaqueShadowCascade].z, lightData.opaqueShadowDepth);
                //lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 4.0 * far;
                float minTransparentDepth = min(lightData.shadowPos[lightData.transparentShadowCascade].z, lightData.transparentShadowDepth);
                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * 3.0 * far;
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                lightData.shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    float distortFactor = getDistortFactor(lightData.shadowPos.xy);
                    lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz, distortFactor);
                    lightData.shadowBias = GetShadowBias(lightData.geoNoL, distortFactor);
                #else
                    lightData.shadowBias = GetShadowBias(lightData.geoNoL);
                #endif

                lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;

                #ifdef SHADOW_DITHER
                    lightData.shadowPos.xy += ditherOffset;
                #endif

                lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos, vec2(0.0));

                //float minOpaqueDepth = min(lightData.shadowPos.z, lightData.opaqueShadowDepth);
                //lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 3.0 * far;
                //float minTransparentDepth = min(lightData.shadowPos.z, lightData.transparentShadowDepth);
                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * 3.0 * far;
            #endif
        #endif

        vec4 finalColor = PbrLighting2(material, lightData, viewPosFinal);

        #ifdef SKY_ENABLED
            if (isEyeInWater != 1) {
                vec3 localViewDir = normalize(localPos);

                vec3 cloudPos;
                cloudPos.y = CLOUD_PLANE_Y_LEVEL - (cameraPosition.y + localPos.y);
                cloudPos.xz = localPos.xz + (localPos.xz / localPos.y) * cloudPos.y;

                vec3 cloudColor = 0.004 * GetSunTransmittance(colortex9, CLOUD_PLANE_Y_LEVEL, skyLightLevels.x) * GetSunLux();
                cloudColor *= 1.0 - rainStrength;

                // TODO: this isn't working!
                if (dot(cloudPos, cloudPos) < dot(viewPos, viewPos)) {
                    float cloudF = GetCloudFactor(cameraPosition, localViewDir);

                    float cloudHorizonFogF = 1.0 - abs(localViewDir.y);
                    cloudF *= 1.0 - pow(cloudHorizonFogF, 8.0);

                    finalColor.rgb = mix(finalColor.rgb, vec3(0.0), cloudF);
                    // TODO: mix opacity?
                }

                #ifdef VL_ENABLED
                    vec3 viewNear = viewDir * near;
                    vec3 viewFar = viewDir * min(length(viewPos), far);

                    vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux(); // * sunColor
                    vec3 lightColor = GetVanillaSkyScattering(viewDir, skyLightLevels, sunColorFinal, moonColor);

                    finalColor.rgb += GetVolumetricLighting(lightData, viewNear, viewFar, lightColor);
                    // TODO: increase alpha with VL
                #endif
            }
        #endif

        return finalColor;
    }
#endif
