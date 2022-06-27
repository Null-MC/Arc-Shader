#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    #ifdef AF_ENABLED
        float manualDeterminant(const in mat2 matrix) {
            return matrix[0].x * matrix[1].y - matrix[0].y * matrix[1].x;
        }

        mat2 inverse2(const in mat2 m) {
            mat2 adj;
            adj[0][0] =  m[1][1];
            adj[0][1] = -m[0][1];
            adj[1][0] = -m[1][0];
            adj[1][1] =  m[0][0];
            return adj / manualDeterminant(m);
        }

        vec4 textureAF(const in sampler2D sampler, const in vec2 uv, const in mat2 dFdXY) {
            mat2 J = inverse2(dFdXY);     // dFdxy: pixel footprint in texture space
            J = transpose(J)*J;                             // quadratic form
            float d = manualDeterminant(J), t = J[0][0]+J[1][1],  // find ellipse: eigenvalues, max eigenvector
                  D = sqrt(abs(t*t-4.0*d)),                 // abs() fix a bug: in weird view angles 0 can be slightly negative
                  V = (t-D)/2.0, v = (t+D)/2.0,                // eigenvalues
                  M = 1.0/sqrt(V), m = 1./sqrt(v);             // = 1./radii^2
            vec2 A = M * normalize(vec2(-J[0][1], J[0][0]-V)); // max eigenvector = main axis

            float lod;
            if (M/m > 16.0) {
                lod = log2(M / 16.0 * viewHeight);
            } else {
                lod = log2(m * viewHeight);
            }

            const float samplesDiv2 = AF_SAMPLES / 2.0;
            vec2 ADivSamples = A / AF_SAMPLES;

            vec2 spriteDimensions = vec2(spriteBounds.z - spriteBounds.x, spriteBounds.w - spriteBounds.y);

            vec4 final;
            final.rgb = vec3(0.0);

            // preserve original alpha to prevent artifacts
            final.a = texture2DLod(sampler, uv, lod).a;

            for (float i = -samplesDiv2 + 0.5; i < samplesDiv2; i++) { // sample along main axis at LOD min-radius
                vec2 sampleUV = uv + ADivSamples * i;
                sampleUV = mod(sampleUV - spriteBounds.xy, spriteDimensions) + spriteBounds.xy; // wrap sample UV to fit inside sprite
                final.rgb += texture2DLod(sampler, sampleUV, lod).rgb;
            }

            final.rgb /= AF_SAMPLES;
            return final;
        }
    #endif

    void PbrLighting(out vec4 colorMap, out vec4 normalMap, out vec4 specularMap, out vec4 lightingMap) {
        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        vec2 atlasCoord = texcoord;

        #ifdef PARALLAX_ENABLED
            float texDepth = 1.0;
            vec3 traceCoordDepth = vec3(1.0);
            vec3 tanViewDir = normalize(tanViewPos);

            if (viewPos.z < PARALLAX_DISTANCE) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    atlasCoord = GetParallaxCoord(tanViewDir, texDepth, traceCoordDepth);
                #else
                    atlasCoord = GetParallaxCoord(dFdXY, tanViewDir, texDepth, traceCoordDepth);
                #endif
            }
        #endif
        
        #ifdef AF_ENABLED
            colorMap = textureAF(texture, atlasCoord, dFdXY);
        #else
            colorMap = texture2DGrad(texture, atlasCoord, dFdXY[0], dFdXY[1]);
        #endif

        #ifndef RENDER_WATER
            if (colorMap.a < alphaTestRef) discard;
            colorMap.a = 1.0;
        #endif

        colorMap *= glcolor;

        #ifdef RENDER_ENTITIES
            //colorMap.rgb *= (1.0 - entityColor.a) + entityColor.rgb * entityColor.a;
            colorMap.rgb = mix(colorMap.rgb, entityColor.rgb, entityColor.a);
        #endif

        #ifdef PARALLAX_SMOOTH
            normalMap.rgb = SampleLinearRGB(normals, atlasCoord, 1.0 / atlasSize);
        #else
            normalMap.rgb = texture2DGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]).rgb;
        #endif

        normalMap.a = 0.0;

        specularMap = texture2DGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);

        vec3 normal;
        normal.xy = normalMap.xy * 2.0 - 1.0;
        normal.z = sqrt(max(1.0 - dot(normal.xy, normal.xy), EPSILON));

        #ifdef PARALLAX_SLOPE_NORMALS
            float dO = max(texDepth - traceCoordDepth.z, 0.0);
            if (dO >= 0.95 / 255.0) {
                #ifdef PARALLAX_USE_TEXELFETCH
                    normal = GetParallaxSlopeNormal(atlasCoord, traceCoordDepth.z, tanViewDir);
                #else
                    normal = GetParallaxSlopeNormal(atlasCoord, dFdXY, traceCoordDepth.z, tanViewDir);
                #endif
            }
        #endif

        const float minSkylightThreshold = 1.0 / 32.0 + EPSILON;
        float shadow = step(minSkylightThreshold, lmcoord.y);

        #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
            #if SHADOW_TYPE == 3
                vec3 _shadowPos[4] = shadowPos;
            #else
                vec4 _shadowPos = shadowPos;
            #endif

            #if defined PARALLAX_ENABLED && defined PARALLAX_SHADOW_FIX
                float depth = 1.0 - traceCoordDepth.z;
                float eyeDepth = 0.0; //depth / max(geoNoV, EPSILON);

                #if SHADOW_TYPE == 3
                    _shadowPos[0] = mix(shadowPos[0], shadowParallaxPos[0], depth) - eyeDepth;
                    _shadowPos[1] = mix(shadowPos[1], shadowParallaxPos[1], depth) - eyeDepth;
                    _shadowPos[2] = mix(shadowPos[2], shadowParallaxPos[2], depth) - eyeDepth;
                    _shadowPos[3] = mix(shadowPos[3], shadowParallaxPos[3], depth) - eyeDepth;
                #else
                    _shadowPos = mix(shadowPos, shadowParallaxPos, depth) - eyeDepth;
                #endif
            #endif

            vec3 tanLightDir = normalize(tanLightPos);
            float NoL = dot(normal, tanLightDir);

            shadow *= step(EPSILON, geoNoL);
            shadow *= step(EPSILON, NoL);

            float lightSSS = 0.0;
            #ifdef SSS_ENABLED
                float materialSSS = GetLabPbr_SSS(specularMap.b);
                if (shadow > EPSILON || materialSSS > EPSILON)
                    shadow *= GetShadowing(_shadowPos, lightSSS);
            #else
                if (shadow > EPSILON) {
                    shadow *= GetShadowing(_shadowPos, lightSSS);

                    // #if SHADOW_COLORS == 1
                    //     vec3 shadowColor = GetShadowColor();

                    //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    //     //also make colors less intense when the block light level is high.
                    //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    //     lightColor *= shadowColor;
                    // #endif
                }
            #endif

            #ifdef PARALLAX_SHADOWS_ENABLED
                if (shadow > EPSILON && traceCoordDepth.z + EPSILON < 1.0) {
                    #ifdef PARALLAX_USE_TEXELFETCH
                        shadow *= GetParallaxShadow(traceCoordDepth, tanLightDir);
                    #else
                        shadow *= GetParallaxShadow(traceCoordDepth, dFdXY, tanLightDir);
                    #endif
                }
            #endif
        #endif
        
        #ifdef RENDER_WATER
            // TODO: blend in deferred output?
        #endif

        normalMap.xy = (normal.xyz * matTBN).xy * 0.5 + 0.5;

        lightingMap = vec4(lmcoord, shadow, lightSSS);
    }
#endif
