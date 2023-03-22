#ifdef RENDER_VERTEX
    void BasicVertex(out vec3 localPos) {
        localPos = gl_Vertex.xyz;
        vec3 normal = gl_Normal;

        #if defined RENDER_TERRAIN || defined RENDER_WATER
            int blockId = int(mc_Entity.x + 0.5);
            float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
        #endif

        #if defined WORLD_SKY_ENABLED && defined RENDER_TERRAIN && WAVING_MODE != WAVING_NONE
            //if (blockId >= 10001 && blockId <= 10004) {
                //float wavingRange = GetWavingRange(skyLight);
                ApplyWavingOffset(localPos, blockId, skyLight);
            //}
        #endif

        #ifdef RENDER_WATER
            if (blockId == BLOCK_WATER) {
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

                #if defined WORLD_WATER_ENABLED && (defined WATER_WAVE_ENABLED || defined PHYSICS_OCEAN)
                    float vY = -at_midBlock.y / 64.0;
                    float posY = saturate(vY + 0.5) * (1.0 - step(0.5, vY + EPSILON));

                    if (posY > EPSILON) {// || (abs(gl_Normal.y) < EPSILON && true)) {
                        //float windSpeed = GetWindSpeed();
                        //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                        // vec3 localPos;

                        // #if MC_VERSION >= 11700 && !defined IS_IRIS
                        //     localPos = vaPosition.xyz + chunkOffset;
                        // #else
                        //     localPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * vec4(pos, 1.0))).xyz;
                        // #endif

                        vec3 _viewPos = (gl_ModelViewMatrix * vec4(localPos, 1.0)).xyz;
                        vec3 _localPos = (gbufferModelViewInverse * vec4(_viewPos, 1.0)).xyz;
                        vec3 worldPos = _localPos + cameraPosition;
                        
                        #ifdef PHYSICS_OCEAN
                            physics_localPosition = localPos;
                            physics_localWaviness = physics_GetWaviness(ivec2(localPos.xz));
                            float waveDepth = physics_waveHeight(localPos, physics_localWaviness, physics_gameTime);
                            physics_localPosition.y += waveDepth;
                        #else
                            float waveMaxDepth = GetWaveDepth(skyLight);
                            float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                            vec3 waterWorldPos = waterWorldScale * worldPos;

                            float waveDepth = 1.0 - GetWaves(waterWorldPos.xz, waveMaxDepth, WATER_OCTAVES_VERTEX).y;
                            waveDepth = -waveDepth * waveMaxDepth * WaterWaveDepthF * posY;
                        #endif

                        localPos.y += waveDepth;
                    }
                #endif
            }
        #endif

        viewPos = (gl_ModelViewMatrix * vec4(localPos, 1.0)).xyz;
        viewNormal = normalize(gl_NormalMatrix * normal);

        localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

        gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);

        #if defined RENDER_TEXTURED || defined RENDER_WEATHER || defined RENDER_BEACONBEAM
            geoNoL = 1.0;
        #else
            #ifdef SHADOW_ENABLED
                vec3 lightDir = GetShadowLightViewDir();
                geoNoL = dot(lightDir, viewNormal);
            #elif defined WORLD_SKY_ENABLED
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

#if defined WORLD_SKY_ENABLED && defined RENDER_FRAG
    vec3 GetFancySkyAmbientLight(const in vec3 localNormal) {
        vec2 sphereCoord = DirectionToUV(localNormal);
        vec3 irradiance = textureLod(BUFFER_IRRADIANCE, sphereCoord, 0).rgb;

        #if !defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE
            irradiance *= 2.0;
        #endif

        return saturate(irradiance) * SKY_FANCY_LUM;
    }
#endif
