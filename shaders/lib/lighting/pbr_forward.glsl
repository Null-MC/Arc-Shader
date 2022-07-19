#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    void ApplyVanillaProperties(inout PbrMaterial material, const in vec4 colorMap) {
        material.albedo.rgb = RGBToLinear(colorMap.rgb);
        material.albedo.a = colorMap.a;

        material.normal = vec3(0.0, 0.0, 1.0);
        material.occlusion = 1.0;

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && defined RENDER_WATER
            material.smoothness = matSmooth;
            material.f0 = matMetal;
            material.scattering = matSSS;
        #else
            material.smoothness = 0.08;
            material.f0 = 0.04;
        #endif
    }

    vec4 PbrLighting() {
        PbrMaterial material;
        float waterDepth = 0.0;

        #ifdef RENDER_WATER
            if (materialId == 1) {
                vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
                float solidViewDepth = textureLod(depthtex1, screenUV, 0).r;
                float solidViewDepthLinear = linearizeDepthFast(solidViewDepth, near, far);
                float waterViewDepthLinear = linearizeDepthFast(gl_FragCoord.z, near, far);
                waterDepth = max(solidViewDepthLinear - waterViewDepthLinear, 0.0);
            }
        #endif

        #if defined RENDER_WATER && defined WATER_FANCY
            if (materialId == 1) {
                material.albedo = vec4(vec3(0.038, 0.068, 0.075), 0.2);
                material.normal = vec3(0.0, 0.0, 1.0);
                material.occlusion = 1.0;
                material.smoothness = 0.98;
                material.f0 = 0.02;

                const float waterPixelSize = rcp(WATER_RESOLUTION);
                float zScale = 20.0;

                vec2 waterLocalPos = rcp(2.0*WATER_RADIUS) * localPos.xz;
                float depth, depthX, depthY;

                #if WATER_WAVE_TYPE == WATER_WAVE_PARALLAX
                    if (
                        waterLocalPos.x > -0.5 && waterLocalPos.x < 0.5 &&
                        waterLocalPos.y > -0.5 && waterLocalPos.y < 0.5
                    ) {
                        vec2 waterTex = waterLocalPos + 0.5;

                            mat2 dFdXY = mat2(dFdx(waterLocalPos), dFdy(waterLocalPos));

                            float texDepth = 1.0;
                            vec3 traceCoordDepth = vec3(1.0);
                            vec3 tanViewDir = normalize(tanViewPos);

                            float viewDist = length(viewPos);
                            if (viewDist < WATER_RADIUS) {
                                waterTex = GetWaterParallaxCoord(waterTex, dFdXY, tanViewDir, viewDist, waterDepth);

                                // TODO: depth-write
                            }

                        depth = texture(BUFFER_WATER_WAVES, waterTex).r;
                        depthX = textureOffset(BUFFER_WATER_WAVES, waterTex, ivec2(1, 0)).r;
                        depthY = textureOffset(BUFFER_WATER_WAVES, waterTex, ivec2(0, 1)).r;
                    }
                    else {
                #endif

                    vec2 waterWorldPos = WATER_SCALE * rcp(2.0*WATER_RADIUS) * (localPos.xz + cameraPosition.xz);

                    vec2 waterWorldPosX = waterWorldPos + vec2(waterPixelSize, 0.0);
                    vec2 waterWorldPosY = waterWorldPos + vec2(0.0, waterPixelSize);

                    int octaves = WATER_OCTAVES_FAR;
                    #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                        float viewDist = length(viewPos) - near;
                        octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, saturate(viewDist / 200.0)));
                    #endif

                    float windSpeed = GetWindSpeed();
                    depth = GetWaves(waterWorldPos, windSpeed, octaves);
                    depthX = GetWaves(waterWorldPosX, windSpeed, octaves);
                    depthY = GetWaves(waterWorldPosY, windSpeed, octaves);
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

            vec2 atlasCoord = texcoord;
            mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));

            #ifdef PARALLAX_ENABLED
                float texDepth = 1.0;
                vec3 traceCoordDepth = vec3(1.0);
                vec3 tanViewDir = normalize(tanViewPos);

                float viewDist = length(viewPos);
                if (viewDist < PARALLAX_DISTANCE)
                    atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);
            #endif

            vec4 colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]) * glcolor;

            #if MATERIAL_FORMAT != MATERIAL_FORMAT_DEFAULT
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

                PopulateMaterial(material, colorMap, normalMap, specularMap);

                #ifndef RENDER_WATER
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

        #if defined RENDER_WATER && defined WATER_FANCY
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

        return PbrLighting2(material, lm, shadow, shadowSSS, viewPos.xyz, waterDepth);
    }
#endif
