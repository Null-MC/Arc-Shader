#define RENDER_DEFERRED
#define RENDER_CSM_CASCADES

varying vec2 texcoord;

#if SHADOW_TYPE == 3
    flat varying float cascadeSizes[4];
    flat varying mat4 matShadowProjections[4];
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
        #endif
	}
#endif

#ifdef RENDER_FRAG
    // uniform sampler2D colortex0;
    uniform sampler2D colortex1;
    // uniform sampler2D colortex2;
    // uniform sampler2D colortex3;

    uniform usampler2D shadowcolor0;
    uniform sampler2D shadowcolor1;
    uniform sampler2D shadowtex1;
    uniform sampler2D depthtex0;

    uniform mat4 shadowProjectionInverse;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 shadowProjection;
    uniform mat4 shadowModelView;
    //uniform float viewWidth;
    //uniform float viewHeight;

    #if SHADOW_TYPE == 3
        #include "/lib/shadows/csm.glsl"
    #elif SHADOW_TYPE == 2
        #include "/lib/shadows/basic.glsl"
    #endif

    #include "/lib/sampling/rsm_151.glsl"
    #include "/lib/lighting/rsm.glsl"

    /* RENDERTARGETS: 5,6 */
    layout(location = 0) out vec4 outColor;
    layout(location = 1) out vec3 outNormalDepth;


	void main() {
        float clipDepth = texture2DLod(depthtex0, texcoord, 0).r;

        vec3 color = vec3(0.0);
        vec2 normal = vec2(0.0);
        if (clipDepth < 1.0) {
            vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;

            vec4 localPos = gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clipPos, 1.0));
            localPos.xyz /= localPos.w;

            normal = texture2DLod(colortex1, texcoord, 0).rg;
            vec3 localNormal = mat3(gbufferModelViewInverse) * RestoreNormalZ(normal);

            // #if SHADOW_TYPE == 3
            //     vec3 shadowViewPos = (shadowModelView * vec4(localPos.xyz, 1.0)).xyz;

            //     int cascade = GetCascadeForScreenPos(clipPos.xy);
            //     vec3 shadowPos = (matShadowProjections[cascade] * vec4(shadowViewPos, 1.0)).xyz;
            // #else
            //     vec4 shadowPos = shadowProjection * (shadowModelView * vec4(localPos.xyz, 1.0));

            //     #if SHADOW_TYPE == 2
            //         float distortFactor = getDistortFactor(shadowPos.xy);
            //         shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
            //     #endif

            //     shadowPos.xyz /= shadowPos.w;
            // #endif

            vec3 shadowViewPos = (shadowModelView * vec4(localPos.xyz, 1.0)).xyz;

            color = GetIndirectLighting_RSM(shadowViewPos, localPos.xyz, localNormal);
        }

        //color = LinearToRGB(color);

		outColor = vec4(color, 1.0); //colortex5
        outNormalDepth = vec3(normal, clipDepth); //colortex6
	}
#endif
