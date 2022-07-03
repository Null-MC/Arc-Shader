#define RENDER_DEFERRED
#define RENDER_RSM

varying vec2 texcoord;

#if SHADOW_TYPE == 3
    flat varying float cascadeSizes[4];
    flat varying mat4 matShadowProjections[4];

    //flat varying vec4 matShadowProjectionParts[4];
    //flat varying vec2 matShadowProjectionOffsets[4];
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

            for (int i = 0; i < 4; i++) {
                matShadowProjections[i] = GetShadowCascadeProjectionMatrix(i);

                // matShadowProjectionParts[i].x = ;
                // matShadowProjectionParts[i].y = ;
                // matShadowProjectionParts[i].z = ;
                // matShadowProjectionParts[i].w = ;
                // matShadowProjectionOffsets[i].x = ;
                // matShadowProjectionOffsets[i].y = ;
            }
        #endif
	}
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex1;
    uniform sampler2D colortex3;
    uniform sampler2D shadowtex1;
    uniform sampler2D depthtex0;
    uniform usampler2D shadowcolor0;

    #if SHADOW_TYPE == 3
        uniform isampler2D shadowcolor1;
    #else
        uniform sampler2D shadowcolor1;
    #endif

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 shadowProjectionInverse;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 shadowProjection;
    uniform mat4 shadowModelView;
    uniform float viewWidth;
    uniform float viewHeight;

    #if SHADOW_TYPE == 3
        uniform float far;

        #include "/lib/shadows/csm.glsl"
        //#include "/lib/depth.glsl"
    #elif SHADOW_TYPE == 2
        #include "/lib/shadows/basic.glsl"
    #endif

    #include "/lib/sampling/rsm_151.glsl"
    #include "/lib/lighting/rsm.glsl"

    /* RENDERTARGETS: 5,6 */
    layout(location = 0) out vec4 outColor;
    layout(location = 1) out vec3 outNormalDepth;


	void main() {
        ivec2 itex = ivec2(texcoord * vec2(viewWidth, viewHeight));
        float clipDepth = texelFetch(depthtex0, itex, 0).r;

        vec3 color = vec3(0.0);
        vec2 normal = vec2(0.0);

        if (clipDepth < 1.0) {
            float skyLight = texelFetch(colortex3, itex, 0).g;

            if (skyLight >= 1.0 / 16.0) {
                normal = texelFetch(colortex1, itex, 0).rg;

                vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;

                vec4 localPos = gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clipPos, 1.0));
                localPos.xyz /= localPos.w;

                vec3 localNormal = mat3(gbufferModelViewInverse) * RestoreNormalZ(normal);

                vec3 shadowViewPos = (shadowModelView * vec4(localPos.xyz, 1.0)).xyz;

                color = GetIndirectLighting_RSM(shadowViewPos, localPos.xyz, localNormal);
            }
        }

		outColor = vec4(color, 1.0);
        outNormalDepth = vec3(normal, clipDepth);
	}
#endif
