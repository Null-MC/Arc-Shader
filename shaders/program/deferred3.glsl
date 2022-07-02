#extension GL_ARB_shading_language_packing : enable

#define RENDER_DEFERRED
#define RENDER_RSM_FULL

varying vec2 texcoord;

#if SHADOW_TYPE == 3
    flat varying float cascadeSizes[4];
    flat varying mat4 matShadowProjections[4];
    //flat varying mat4 matShadowProjectionsInv[4];
#endif

#ifdef RENDER_VERTEX
    #if SHADOW_TYPE == 3
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

            // matShadowProjectionsInv[0] = inverse(matShadowProjections[0]);
            // matShadowProjectionsInv[1] = inverse(matShadowProjections[1]);
            // matShadowProjectionsInv[2] = inverse(matShadowProjections[2]);
            // matShadowProjectionsInv[3] = inverse(matShadowProjections[3]);
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

    #if SHADOW_TYPE == 3
        #include "/lib/shadows/csm.glsl"
    #elif SHADOW_TYPE == 2
        #include "/lib/shadows/basic.glsl"
    #endif

    #include "/lib/sampling/rsm_151.glsl"
    #include "/lib/lighting/rsm.glsl"


	void main() {
        ivec2 itex = ivec2(texcoord * vec2(viewWidth, viewHeight));
        ivec2 itexQ = ivec2(texcoord * vec2(viewWidth, viewHeight) * RSM_SCALE);
        float clipDepth = texelFetch(depthtex0, itex, 0).r;

        vec3 final = vec3(0.0);
        if (clipDepth < 1.0) {
            vec2 normalTex = texelFetch(colortex1, itex, 0).rg;

            //vec2 rsmNormal = texelFetch(colortex6, itexQ, 0).rg;
            //float rsmDepth = texture2DLod(colortex6, texcoord, 0).b;
            vec3 shit = texture2DLod(colortex6, texcoord, 0).rgb;
            vec2 rsmNormal = shit.xy;
            float rsmDepth = shit.z;

            vec3 viewNormal = RestoreNormalZ(normalTex);
            vec3 rsmViewNormal = RestoreNormalZ(rsmNormal);

            //final = vec3(abs(rsmNormalDepth.z - clipDepth));
            //float d = dot(rsmViewNormal, viewNormal);
            //final = vec3(d * d);

            if (abs(rsmDepth - clipDepth) < 0.001 && dot(rsmViewNormal, viewNormal) > 0.8) {
                final = texture2DLod(colortex5, texcoord, 0).rgb;
            }
            else {
                float skyLight = texelFetch(colortex3, itex, 0).g;

                if (skyLight >= 1.0 / 16.0) {
                    vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;

                    vec4 localPos = gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clipPos, 1.0));
                    localPos.xyz /= localPos.w;

                    //vec2 normalTex = texture2DLod(colortex1, texcoord, 0).rg;
                    vec3 localNormal = mat3(gbufferModelViewInverse) * viewNormal;

                    vec3 shadowViewPos = (shadowModelView * vec4(localPos.xyz, 1.0)).xyz;

                    final = GetIndirectLighting_RSM(shadowViewPos, localPos.xyz, localNormal);
                    //final = LinearToRGB(final);
                    //final = vec3(1.0, 0.0, 0.0);
                }
            }
        }


	/* DRAWBUFFERS:7 */
		gl_FragData[0] = vec4(final, 1.0); //colortex7
	}
#endif
