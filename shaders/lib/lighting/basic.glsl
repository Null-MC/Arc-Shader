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
                    // if (all(greaterThan(mc_midTexCoord, vec4(EPSILON)))) {
                    //     if (isEyeInWater == 1 && gl_Normal.y > 0.01) {
                    //         //the bottom face doesn't have a backface.
                    //         gl_Position = vec4(10.0);
                    //         return;
                    //     }
                    //     if (isEyeInWater == 0 && gl_Normal.y < -0.01) {
                    //         //sneaky back face of top needs weird checks.
                    //         if (at_midBlock.y < 30.75) {
                    //             gl_Position = vec4(10.0);
                    //             return;
                    //         }
                    //     }
                    // }
                #endif

                #if defined WORLD_WATER_ENABLED && (WATER_WAVE_TYPE == WATER_WAVE_VERTEX || defined PHYSICS_OCEAN)
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
                            physics_localPosition = pos;
                            physics_localWaviness = physics_GetWaviness(ivec2(pos.xz));
                            float depth = physics_waveHeight(pos, PHYSICS_ITERATIONS_OFFSET, physics_localWaviness, physics_gameTime);
                            physics_localPosition.y += depth;
                        #else
                            float waveDepth = GetWaveDepth(skyLight);
                            float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                            vec3 waterWorldPos = waterWorldScale * worldPos;

                            float depth = 1.0 - GetWaves(waterWorldPos.xz, waveDepth, WATER_OCTAVES_VERTEX).y;
                            depth = -depth * waveDepth * WaterWaveDepthF * posY;
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
                vec3 lightDir = GetShadowLightViewDir();
                geoNoL = dot(lightDir, viewNormal);
            #elif defined SKY_ENABLED
                vec3 upDir = normalize(upPosition);
                vec3 sunLightDir = GetSunViewDir();
                vec3 moonLightDir = GetMoonViewDir();
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

#if defined SKY_ENABLED && defined RENDER_FRAG
    vec3 GetFancySkyAmbientLight(const in vec3 localNormal, const in float skyLight) {
        vec2 sphereCoord = DirectionToUV(localNormal);
        vec3 irradiance = textureLod(BUFFER_IRRADIANCE, sphereCoord, 0).rgb;
        return irradiance * SKY_FANCY_LUM * smoothstep(0.0, 1.0, skyLight);
    }
#endif
