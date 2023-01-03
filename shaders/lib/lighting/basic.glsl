#ifdef RENDER_VERTEX
    void BasicVertex(inout vec3 pos) {
        vec3 normal = gl_Normal;

        #if defined RENDER_TERRAIN || defined RENDER_WATER
            float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
        #endif

        #if defined SKY_ENABLED && defined RENDER_TERRAIN && defined ENABLE_WAVING
            if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0) {
                float wavingRange = GetWavingRange(skyLight);
                pos += GetWavingOffset(wavingRange);
            }
        #endif

        #ifdef RENDER_WATER
            if (abs(mc_Entity.x - 100.0) < 0.5) {
                #ifndef PHYSICS_OCEAN
                    if (gl_Normal.y > 0.01) {
                        //the bottom face doesn't have a backface.
                        if (isEyeInWater != 0) {
                            gl_Position = vec4(10.0);
                            return;
                        }
                    }
                    else if (gl_Normal.y < -0.01) {
                        //sneaky back face of top needs weird checks.
                        if (at_midBlock.y < 30.75 && isEyeInWater == 0) {
                            gl_Position = vec4(10.0);
                            return;
                        }
                    }
                    // else {
                    //     if (dot(gl_Normal, at_midBlock) > 0.0) {
                    //         gl_Position = vec4(10.0);
                    //         return;
                    //     }
                    // }
                #endif

                #if defined WATER_ENABLED && WATER_WAVE_TYPE == WATER_WAVE_VERTEX
                    //#if MC_VERSION >= 11700
                        float vY = -at_midBlock.y / 64.0;
                        float posY = saturate(vY + 0.5) * (1.0 - step(0.5, vY + EPSILON));
                    //#else
                    //    float posY = step(EPSILON, gl_Normal.y);
                    //#endif

                    if (posY > EPSILON) {// || (abs(gl_Normal.y) < EPSILON && true)) {
                        //float windSpeed = GetWindSpeed();
                        //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                        vec3 localPos;

                        #if MC_VERSION >= 11700 && (SHADER_PLATFORM != PLATFORM_IRIS || defined IRIS_FEATURE_CHUNK_OFFSET)
                            localPos = vaPosition.xyz + chunkOffset;
                        #else
                            localPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * vec4(pos, 1.0))).xyz;
                        #endif

                        vec3 worldPos = localPos + cameraPosition;
                        
                        #ifdef PHYSICS_OCEAN
                            //float waveScaledIterations = 1.0 - saturate((length(localPos) - 20.0) / 60.0);
                            //float waveIterations = max(6.0, PHYSICS_ITERATIONS_OFFSET * waveScaledIterations);

                            physics_localPosition = pos;
                            float waviness = textureLod(physics_waviness, pos.xz / vec2(textureSize(physics_waviness, 0)), 0).r;
                            float depth = physics_waveHeight(pos, PHYSICS_ITERATIONS_OFFSET, waviness, physics_gameTime);

                            #ifndef WATER_FANCY
                                vec3 waterWorldPosX = worldPos + vec3(1.0, 0.0, 0.0);
                                float depthX = physics_waveHeight(waterWorldPosX, PHYSICS_ITERATIONS_OFFSET, waviness, physics_gameTime);
                                vec3 pX = vec3(1.0, 0.0, depthX - depth);

                                vec3 waterWorldPosY = worldPos + vec3(0.0, 0.0, 1.0);
                                float depthY = physics_waveHeight(waterWorldPosY, PHYSICS_ITERATIONS_OFFSET, waviness, physics_gameTime);
                                vec3 pY = vec3(0.0, 1.0, depthY - depth);

                                normal = normalize(cross(pX, pY)).xzy;
                            #endif
                        #else
                            float waveDepth = GetWaveDepth(skyLight);
                            float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                            vec3 waterWorldPos = waterWorldScale * worldPos;

                            float depth = 1.0 - GetWaves(waterWorldPos.xz, waveDepth, WATER_OCTAVES_VERTEX);
                            depth = -(1.0 - depth) * waveDepth * WaterWaveDepthF * posY;

                            #ifndef WATER_FANCY
                                vec2 waterWorldPosX = waterWorldPos.xz + vec2(waterWorldScale, 0.0);
                                float depthX = GetWaves(waterWorldPosX, waveDepth, WATER_OCTAVES_VERTEX);
                                vec3 pX = vec3(1.0, 0.0, (depthX - depth) * waveDepth);

                                vec2 waterWorldPosY = waterWorldPos.xz + vec2(0.0, waterWorldScale);
                                float depthY = GetWaves(waterWorldPosY, waveDepth, WATER_OCTAVES_VERTEX);
                                vec3 pY = vec3(0.0, 1.0, (depthY - depth) * waveDepth);

                                normal = normalize(cross(pX, pY)).xzy;
                            #endif
                        #endif

                        pos.y += depth;
                    }
                #endif
            }
            // else if (abs(mc_Entity.x - 101.0) < 0.5) {
            //     if (gl_Normal.y > 0.01) {
            //         //the bottom face doesn't have a backface.
            //     }
            //     else if (gl_Normal.y < -0.01) {
            //         //sneaky back face of top needs weird checks.
            //         if (at_midBlock.y < 30.75) {
            //            gl_Position = vec4(10.0);
            //            return;
            //         }
            //     }
            //     else {
            //         if (dot(gl_Normal, at_midBlock) > 0.0) {
            //             gl_Position = vec4(10.0);
            //             return;
            //         }
            //     }
            // }
        #endif

        viewPos = (gl_ModelViewMatrix * vec4(pos, 1.0)).xyz;
        viewNormal = normalize(gl_NormalMatrix * normal);
        gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);

        // #ifdef RENDER_ENTITIES
        //     if (entityId == 829925)
        //         viewNormal = normal;
        // #endif

        // #ifdef RENDER_TEXTURED
        //     vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
        //     vec2 coordNMid = texcoord - coordMid;

        //     atlasBounds[0] = min(texcoord, coordMid - coordNMid);
        //     atlasBounds[1] = abs(coordNMid) * 2.0;

        //     //localCoord = sign(coordNMid) * 0.5 + 0.5;
        // #endif

        #if defined RENDER_TEXTURED || defined RENDER_WEATHER || defined RENDER_BEACONBEAM
            // TODO: extract billboard direction from view matrix?

            geoNoL = 1.0;
        #else
            #ifdef SHADOW_ENABLED
                vec3 lightDir = normalize(shadowLightPosition);
                geoNoL = dot(lightDir, viewNormal);
            #elif defined SKY_ENABLED
                vec3 upDir = normalize(upPosition);
                vec3 sunLightDir = normalize(sunPosition);
                vec3 moonLightDir = normalize(moonPosition);
                float sunNoL = dot(sunLightDir, upDir);
                float moonNoL = dot(moonLightDir, upDir);

                vec3 lightDir;
                if (sunNoL > moonNoL) lightDir = sunLightDir;
                else lightDir = moonLightDir;

                geoNoL = dot(lightDir, viewNormal);
            #else
                geoNoL = 1.0;
            #endif
        #endif

        #ifdef AF_ENABLED
            vec2 spriteRadius = abs(texcoord - mc_midTexCoord.xy);
            vec2 bottomLeft = mc_midTexCoord.xy - spriteRadius;
            vec2 topRight = mc_midTexCoord.xy + spriteRadius;
            spriteBounds = vec4(bottomLeft, topRight);
        #endif
    }
#endif

#ifdef RENDER_FRAG
    #ifdef SKY_ENABLED
        vec3 GetSkyAmbientLight(const in LightData lightData, const in vec3 normal) {
            vec3 upDir = normalize(upPosition);
            vec3 sunLightDir = normalize(sunPosition);
            vec3 moonLightDir = normalize(moonPosition);

            vec2 skyLightLevels;
            skyLightLevels.x = dot(upDir, sunLightDir);
            skyLightLevels.y = dot(upDir, moonLightDir);

            //vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);

            //vec3 sunLightLux = GetSunLightLuxColor(skyLightTemp.x, skyLightLevels.x);
            vec3 sunColorFinal = lightData.sunTransmittance * GetSunLuxColor() * smoothstep(-0.1, 0.3, skyLightLevels.x);
            vec3 result = sunColorFinal * (dot(normal, sunLightDir) * 0.2 + 0.3);

            //vec3 moonLightLux = GetMoonLightLuxColor(skyLightTemp.y, skyLightLevels.y);
            vec3 moonColorFinal = lightData.moonTransmittance * GetMoonLuxColor() * GetMoonPhaseLevel() * smoothstep(-0.1, 0.3, skyLightLevels.y);
            result += moonColorFinal * (dot(normal, moonLightDir) * 0.2 + 0.3);

            // float skyLux = skyLightLevels.x * DaySkyLux + skyLightLevels.y * NightSkyLux;
            // vec3 skyLightColorLux = RGBToLinear(skyColor) * skyLux;
            // skyLightColorLux *= saturate(dot(normal, upDir) * 0.3 + 0.6);

            vec3 skyColorLux = RGBToLinear(skyColor);// * skyTint;
            if (all(lessThan(skyColorLux, vec3(EPSILON)))) skyColorLux = vec3(1.0);
            skyColorLux = normalize(skyColorLux);

            result += (sunColorFinal + moonColorFinal) * skyColorLux * mix(0.1, 0.01, wetness);

            //return MinWorldLux + sunLightLux + moonLightLux;
            //result += skyColorLux;

            return result;
        }
    #endif
#endif
