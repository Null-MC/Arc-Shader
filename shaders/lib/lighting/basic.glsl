#ifdef RENDER_VERTEX
    void BasicVertex(out mat3 viewTBN) {
        vec3 pos = gl_Vertex.xyz;

        #if defined RENDER_TERRAIN && defined ENABLE_WAVING
            if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
                pos += GetWavingOffset();
        #endif

        //viewPos = mat3(gl_ModelViewMatrix) * pos;
        viewPos = (gl_ModelViewMatrix * vec4(pos, 1.0)).xyz;

        viewNormal = normalize(gl_NormalMatrix * gl_Normal);

        #ifdef RENDER_TEXTURED
            // TODO: extract billboard direction from view matrix?

            geoNoL = 1.0;
        #else
            //vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
            vec3 viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
            vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * at_tangent.w);

            mat3 matModelViewInv = mat3(gbufferModelViewInverse);
            vec3 localNormal = matModelViewInv * viewNormal;
            vec3 localBinormal = matModelViewInv * viewBinormal;
            vec3 localTangent = matModelViewInv * viewTangent;

            matTBN = mat3(
                localTangent.x, localBinormal.x, localNormal.x,
                localTangent.y, localBinormal.y, localNormal.y,
                localTangent.z, localBinormal.z, localNormal.z);

            viewTBN = mat3(
                viewTangent.x, viewBinormal.x, viewNormal.x,
                viewTangent.y, viewBinormal.y, viewNormal.y,
                viewTangent.z, viewBinormal.z, viewNormal.z);

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

        gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
    }
#endif

#ifdef RENDER_FRAG
    <empty>
#endif
