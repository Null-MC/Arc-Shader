#ifdef RENDER_VERTEX
    void BasicVertex(out mat3 viewTBN) {
        vec3 pos = gl_Vertex.xyz;

        viewNormal = normalize(gl_NormalMatrix * gl_Normal);

        #if defined RENDER_TERRAIN && defined ENABLE_WAVING
            if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
                pos += GetWavingOffset();
        #endif

        #if defined RENDER_WATER && WATER_WAVE_TYPE == WATER_WAVE_VERTEX
            if (mc_Entity.x == 100.0) {
                float windSpeed = GetWindSpeed();
                
                float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                vec2 waterWorldPos = waterWorldScale * (pos.xz + cameraPosition.xz);
                float depth = GetWaves(waterWorldPos, windSpeed, WATER_OCTAVES_VERTEX);
                pos.y -= (1.0 - depth) * WATER_WAVE_DEPTH;

                #ifndef WATER_FANCY
                    vec2 waterWorldPosX = waterWorldPos + vec2(waterWorldScale, 0.0);
                    vec2 waterWorldPosY = waterWorldPos + vec2(0.0, waterWorldScale);

                    //depth = texture(BUFFER_WATER_WAVES, waterTex).r;
                    float depthX = GetWaves(waterWorldPosX, windSpeed, WATER_OCTAVES_VERTEX);
                    float depthY = GetWaves(waterWorldPosY, windSpeed, WATER_OCTAVES_VERTEX);

                    vec3 pX = vec3(1.0, 0.0, (depthX - depth) * WATER_WAVE_DEPTH);
                    vec3 pY = vec3(0.0, 1.0, (depthY - depth) * WATER_WAVE_DEPTH);
                    
                    vec3 waterNormal = normalize(cross(pX, pY));
                    viewNormal = normalize(gl_NormalMatrix * waterNormal.xzy);
                #endif
            }
        #endif

        #if defined RENDER_TEXTURED || defined RENDER_WEATHER || defined RENDER_BEACONBEAM
            // TODO: extract billboard direction from view matrix?

            geoNoL = 1.0;
        #else
            vec3 viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
            vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * at_tangent.w);

            viewTBN = mat3(
                viewTangent.x, viewBinormal.x, viewNormal.x,
                viewTangent.y, viewBinormal.y, viewNormal.y,
                viewTangent.z, viewBinormal.z, viewNormal.z);

            matTBN = viewTBN;

            #if defined SHADOW_ENABLED
                tanLightPos = viewTBN * shadowLightPosition;

                vec3 lightDir = normalize(shadowLightPosition);
                geoNoL = dot(lightDir, viewNormal);
            #else
                geoNoL = 1.0;
            #endif
        #endif

        viewPos = (gl_ModelViewMatrix * vec4(pos, 1.0)).xyz;

        gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);

        #if defined SHADOW_ENABLED && SHADOW_TYPE != 0 && !defined RENDER_SHADOW
            ApplyShadows(viewPos);
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
    vec3 GetSkyAmbientLight(const in vec3 normal) {
        vec3 upDir = normalize(upPosition);
        vec3 sunLightDir = normalize(sunPosition);
        vec3 moonLightDir = normalize(moonPosition);

        vec2 skyLightLevels;
        skyLightLevels.x = dot(upDir, sunLightDir);
        skyLightLevels.y = dot(upDir, moonLightDir);

        vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);

        vec3 sunLightLum = GetSunLightColor(skyLightTemp.x, skyLightLevels.x) * SunLux;
        sunLightLum *= dot(normal, sunLightDir) * 0.5 + 0.5;

        vec3 moonLightLum = GetMoonLightColor(skyLightTemp.y, skyLightLevels.y) * MoonLux;
        moonLightLum *= dot(normal, moonLightDir) * 0.5 + 0.5;

        vec3 skyLightLum = RGBToLinear(skyColor);

        return 0.1 * (skyLightLum + sunLightLum + moonLightLum);
    }
#endif
