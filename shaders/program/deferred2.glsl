#extension GL_ARB_texture_query_levels : enable

#define RENDER_DEFERRED
#define RENDER_RSM

#if defined RENDER_VERTEX && defined RSM_ENABLED
    out vec2 texcoord;
    flat out float exposure;
    
    uniform float screenBrightness;
    uniform float viewWidth;
    uniform float viewHeight;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        flat out float cascadeSizes[4];
        flat out mat4 matShadowProjections[4];

        //flat varying vec4 matShadowProjectionParts[4];
        //flat varying vec2 matShadowProjectionOffsets[4];
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        uniform mat4 shadowModelView;
        uniform float near;
        uniform float far;

        #if MC_VERSION >= 11700 && (defined IS_OPTIFINE || defined IRIS_FEATURE_CHUNK_OFFSET)
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

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform int heldBlockLightValue;
        
        uniform float rainStrength;
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;
        uniform int moonPhase;

        #include "/lib/lighting/blackbody.glsl"
        #include "/lib/world/sky.glsl"
    #endif

    #include "/lib/camera/exposure.glsl"


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        exposure = GetExposure();

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
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

#if defined RENDER_FRAG && defined RSM_ENABLED
    in vec2 texcoord;
    flat in float exposure;

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        flat in float cascadeSizes[4];
        flat in mat4 matShadowProjections[4];

        //flat varying vec4 matShadowProjectionParts[4];
        //flat varying vec2 matShadowProjectionOffsets[4];
    #endif

    uniform usampler2D BUFFER_DEFERRED;
    uniform usampler2D shadowcolor1;
    uniform sampler2D depthtex0;

    #if defined SHADOW_ENABLE_HWCOMP && !defined IRIS_FEATURE_SEPARATE_HW_SAMPLERS
        uniform sampler2D shadowtex0;
    #else
        uniform sampler2D shadowtex1;
    #endif

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 shadowProjectionInverse;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 shadowProjection;
    uniform mat4 shadowModelView;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float far;

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
    #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
        #include "/lib/shadows/basic.glsl"
    #endif

    #if RSM_SAMPLE_COUNT == 400
        #include "/lib/sampling/rsm_400.glsl"
    #elif RSM_SAMPLE_COUNT == 200
        #include "/lib/sampling/rsm_200.glsl"
    #else
        #include "/lib/sampling/rsm_100.glsl"
    #endif

    #include "/lib/rsm.glsl"

    /* RENDERTARGETS: 8,9 */
    out vec3 outColor0;
    #ifdef RSM_UPSCALE
        out float outColor1;
    #endif


	void main() {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        ivec2 itexFull = ivec2(texcoord * viewSize);

        float clipDepth = texelFetch(depthtex0, itexFull, 0).r;
        vec3 color = vec3(0.0);

        if (clipDepth < 1.0) {
            uvec2 deferredNormalLightingData = texelFetch(BUFFER_DEFERRED, itexFull, 0).ga;

            vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;
            vec3 localPos = unproject(gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clipPos, 1.0)));
            vec3 shadowViewPos = (shadowModelView * vec4(localPos, 1.0)).xyz;

            vec3 normalMap = unpackUnorm4x8(deferredNormalLightingData.r).xyz;
            vec3 viewNormal = normalize(normalMap * 2.0 - 1.0);

            vec3 shadowViewNormal = mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * viewNormal);

            #ifdef LIGHTLEAK_FIX
                float lightingMap = unpackUnorm4x8(deferredNormalLightingData.g).g;
                if (lightingMap >= 1.0 / 16.0) color = GetIndirectLighting_RSM(shadowViewPos, shadowViewNormal);
            #else
                color = GetIndirectLighting_RSM(shadowViewPos, shadowViewNormal);
            #endif
        }

        outColor0 = clamp(color, vec3(0.0), vec3(65000.0));

        #ifdef RSM_UPSCALE
            outColor1 = clipDepth;
        #endif
	}
#endif

// Temporary fix for disabling on Iris
#ifndef RSM_ENABLED
    void main() {
        /* RENDERTARGETS: 8,9 */
    }
#endif
