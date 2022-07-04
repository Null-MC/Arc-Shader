#extension GL_ARB_shading_language_packing : enable

#define RENDER_DEFERRED
#define RENDER_RSM_FULL

varying vec2 texcoord;

#if SHADOW_TYPE == 3
    flat varying float cascadeSizes[4];
    flat varying mat4 matShadowProjections[4];
#endif

#ifdef RENDER_VERTEX
    #if SHADOW_TYPE == 3
        uniform mat4 shadowModelView;
        uniform float near;
        uniform float far;

        #if MC_VERSION >= 11700 && defined IS_OPTIFINE
            uniform vec3 chunkOffset;
        #else
            uniform mat4 gbufferModelViewInverse;
        #endif

        #ifdef IS_OPTIFINE
            // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
            uniform mat4 gbufferPreviousModelView;
            uniform mat4 gbufferPreviousProjection;
        #else
            uniform mat4 gbufferModelView;
            uniform mat4 gbufferProjection;
        #endif

        #include "/lib/shadows/csm.glsl"
    #endif


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #if SHADOW_TYPE == 3
            cascadeSizes[0] = GetCascadeDistance(0);
            cascadeSizes[1] = GetCascadeDistance(1);
            cascadeSizes[2] = GetCascadeDistance(2);
            cascadeSizes[3] = GetCascadeDistance(3);

            matShadowProjections[0] = GetShadowCascadeProjectionMatrix(0);
            matShadowProjections[1] = GetShadowCascadeProjectionMatrix(1);
            matShadowProjections[2] = GetShadowCascadeProjectionMatrix(2);
            matShadowProjections[3] = GetShadowCascadeProjectionMatrix(3);
        #endif
	}
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex1;
    uniform sampler2D colortex3;
    uniform sampler2D colortex5;
    uniform sampler2D colortex6;
    uniform usampler2D shadowcolor0;
    uniform sampler2D shadowtex1;
    uniform sampler2D depthtex0;

    #if SHADOW_TYPE == 3
        uniform isampler2D shadowcolor1;
    #else
        uniform sampler2D shadowcolor1;
    #endif

    uniform mat4 shadowProjectionInverse;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 shadowProjection;
    uniform mat4 shadowModelView;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float near;
    uniform float far;

    #if SHADOW_TYPE == 3
        #include "/lib/shadows/csm.glsl"
    #elif SHADOW_TYPE == 2
        #include "/lib/shadows/basic.glsl"
    #endif

    #if RSM_SAMPLE_COUNT == 400
        #include "/lib/sampling/rsm_400.glsl"
    #elif RSM_SAMPLE_COUNT == 200
        #include "/lib/sampling/rsm_200.glsl"
    #else
        #include "/lib/sampling/rsm_100.glsl"
    #endif

    #include "/lib/depth.glsl"
    #include "/lib/rsm.glsl"


	void main() {
        const float rsm_scale = 1.0 / exp2(RSM_SCALE);

        ivec2 itexFull = ivec2(texcoord * vec2(viewWidth, viewHeight));
        float clipDepth = texelFetch(depthtex0, itexFull, 0).r;

        vec3 final = vec3(0.0);
        if (clipDepth < 1.0) {
            vec2 normalTex = texelFetch(colortex1, itexFull, 0).rg;

            vec2 texLow = texcoord * rsm_scale;
            //ivec2 itexLow = ivec2(texLow * vec2(viewWidth, viewHeight));
            vec4 rsmDepths = textureGather(colortex6, texLow, 0);
            float rsmDepthMin = min(min(rsmDepths.x, rsmDepths.y), min(rsmDepths.z, rsmDepths.w));
            float rsmDepthMax = max(max(rsmDepths.x, rsmDepths.y), max(rsmDepths.z, rsmDepths.w));

            float rsmDepthMinLinear = linearizeDepth(rsmDepthMin * 2.0 - 1.0, near, far);
            float rsmDepthMaxLinear = linearizeDepth(rsmDepthMax * 2.0 - 1.0, near, far);

            vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;
            vec4 viewPos = gbufferProjectionInverse * vec4(clipPos, 1.0);
            //vec3 rsmViewNormal = RestoreNormalZ(rsmNormalDepth.xy);

            vec3 viewNormal = RestoreNormalZ(normalTex);

            //float dist = clamp((-viewPos.z - near) / (far - near), 0.0, 1.0);
            //float depthThreshold = mix(0.1, 0.001, dist) / (far - near);
            float clipDepthLinear = linearizeDepth(clipDepth * 2.0 - 1.0, near, far);
            float depthThreshold = 0.1 + 0.0125 * clipDepthLinear*clipDepthLinear;

            bool depthTest = abs(rsmDepthMinLinear - clipDepthLinear) <= depthThreshold
                          && abs(rsmDepthMaxLinear - clipDepthLinear) <= depthThreshold;
            //bool normalTest = dot(rsmViewNormal, viewNormal) > 0.2;

            if (depthTest) {
                final = texture2DLod(colortex5, texLow, 0).rgb;
            }
            else {
                float skyLight = texelFetch(colortex3, itexFull, 0).g;

                if (skyLight >= 1.0 / 16.0) {
                    vec4 localPos = gbufferModelViewInverse * viewPos;
                    localPos.xyz /= localPos.w;

                    vec3 localNormal = mat3(gbufferModelViewInverse) * viewNormal;

                    vec3 shadowViewPos = (shadowModelView * vec4(localPos.xyz, 1.0)).xyz;

                    final = GetIndirectLighting_RSM(shadowViewPos, localPos.xyz, localNormal);

                    #if DEBUG_SHADOW_BUFFER == DEBUG_VIEW_RSM
                        final = mix(final, vec3(1.0, 0.0, 0.0), 0.25);
                    #endif
                }
            }

            //final = texture2DLod(colortex5, texLow, 0).rgb;
            //final = vec3(rsmDepth);
        }


	/* DRAWBUFFERS:5 */
		gl_FragData[0] = vec4(final, 1.0);
	}
#endif
