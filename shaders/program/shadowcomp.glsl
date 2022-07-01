#define RENDER_SHADOWCOMP

varying vec2 texcoord;

// #if SHADOW_TYPE == 3
//     flat varying float cascadeSizes[4];
//     flat varying mat4 matShadowProjectionsInv[4];
// #endif

#ifdef RENDER_VERTEX
    // #if SHADOW_TYPE == 3
    //     uniform float near;
    //     uniform float far;

    //     #if MC_VERSION >= 11700 && defined IS_OPTIFINE
    //         uniform vec3 chunkOffset;
    //     #else
    //         uniform mat4 gbufferModelViewInverse;
    //     #endif

    //     #ifdef IS_OPTIFINE
    //         // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
    //         uniform mat4 gbufferPreviousModelView;
    //         uniform mat4 gbufferPreviousProjection;
    //     #else
    //         uniform mat4 gbufferModelView;
    //         uniform mat4 gbufferProjection;
    //     #endif

    //     #include "/lib/shadows/csm.glsl"
    // #endif


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        // #if SHADOW_TYPE == 3
        //     cascadeSizes[0] = GetCascadeDistance(0);
        //     cascadeSizes[1] = GetCascadeDistance(1);
        //     cascadeSizes[2] = GetCascadeDistance(2);
        //     cascadeSizes[3] = GetCascadeDistance(3);

        //     matShadowProjectionsInv[0] = inverse(GetShadowCascadeProjectionMatrix(0));
        //     matShadowProjectionsInv[1] = inverse(GetShadowCascadeProjectionMatrix(1));
        //     matShadowProjectionsInv[2] = inverse(GetShadowCascadeProjectionMatrix(2));
        //     matShadowProjectionsInv[3] = inverse(GetShadowCascadeProjectionMatrix(3));
        // #endif
	}
#endif

#ifdef RENDER_FRAG
    uniform sampler2D shadowtex0;

    uniform mat4 shadowProjectionInverse;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 shadowProjection;
    uniform mat4 shadowModelView;

    #include "/lib/shadows/csm.glsl"

    /* RENDERTARGETS: 1 */
    layout(location = 0) out uint outIndex;


    float SampleDepth(const in vec2 shadowPos) {
        #if !defined IS_OPTIFINE && defined SHADOW_ENABLE_HWCOMP
            return texture2D(shadowtex1, shadowPos).r;
        #else
            return texture2D(shadowtex0, shadowPos).r;
        #endif
    }

	void main() {
        outIndex = -1;

        float depth = 1.0;
        for (int i = 0; i < 4; i++) {
            vec2 shadowTilePos = GetShadowCascadeClipPos(i);
            vec2 uv = shadowTilePos + 0.5 * texcoord;
            float texDepth = SampleDepth(uv);

            //vec3 viewPos = (matShadowProjectionsInv[i]).xyz;

            if (texDepth < depth) {
                depth = texDepth;
                outIndex = i;
            }
        }
	}
#endif
