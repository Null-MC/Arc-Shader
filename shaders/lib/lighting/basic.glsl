#ifdef RENDER_VERTEX
    void BasicVertex(out mat3 viewTBN) {
        vec3 pos = gl_Vertex.xyz;

        #if defined RENDER_TERRAIN && defined ENABLE_WAVING
            if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
                pos += GetWavingOffset();
        #endif

        viewPos = (gl_ModelViewMatrix * vec4(pos, 1.0)).xyz;

        viewNormal = normalize(gl_NormalMatrix * gl_Normal);

        gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);

        #if defined RENDER_TEXTURED || defined RENDER_BEACONBEAM
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

            #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
                tanLightPos = viewTBN * shadowLightPosition;

                vec3 lightDir = normalize(shadowLightPosition);
                geoNoL = dot(lightDir, viewNormal);
            #else
                geoNoL = 1.0;
            #endif
        #endif

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
        float sunLightStrength = max(dot(upDir, sunLightDir), 0.0);
        float sunLightNormal = max(dot(normal, sunLightDir), 0.0);
        vec3 sunLight = sunColor * sunLightStrength * sunLightNormal * sunIntensity;

        vec3 moonLightDir = normalize(moonPosition);
        float moonLightStrength = max(dot(upDir, moonLightDir), 0.0);
        float moonLightNormal = max(dot(normal, moonLightDir), 0.0);
        vec3 moonLight = moonColor * moonLightStrength * moonLightNormal * moonIntensity;

        return SHADOW_BRIGHTNESS * (skyColor + sunLight + moonLight);
    }
#endif
