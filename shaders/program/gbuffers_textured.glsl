#extension GL_ARB_shading_language_packing : enable

#define RENDER_GBUFFER
#define RENDER_TEXTURED

#undef PARALLAX_ENABLED
#undef AF_ENABLED

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying float geoNoL;

#ifdef SHADOW_ENABLED
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;

    flat varying vec3 skyLightColor;

	#if SHADOW_TYPE == 3
		varying vec3 shadowPos[4];
        varying vec3 shadowParallaxPos[4];
		varying vec2 shadowProjectionSizes[4];
        varying float cascadeSizes[4];
        flat varying int shadowCascade;
	#elif SHADOW_TYPE != 0
		varying vec4 shadowPos;
        varying vec4 shadowParallaxPos;
	#endif
#endif

#ifdef RENDER_VERTEX
	uniform mat4 gbufferModelView;
	uniform mat4 gbufferModelViewInverse;

    uniform float rainStrength;

	#ifdef SHADOW_ENABLED
		uniform mat4 shadowModelView;
		uniform mat4 shadowProjection;
		uniform vec3 shadowLightPosition;
		uniform float far;

		#if SHADOW_TYPE == 3
			attribute vec3 at_midBlock;

            #ifdef IS_OPTIFINE
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

			uniform mat4 gbufferProjection;
			uniform float near;

			#include "/lib/shadows/csm.glsl"
			#include "/lib/shadows/csm_render.glsl"
		#elif SHADOW_TYPE != 0
			#include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
		#endif
	#endif

    #include "/lib/world/sky.glsl"
    #include "/lib/lighting/basic.glsl"


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;

        mat3 matViewTBN;
        BasicVertex(matViewTBN);

        skyLightColor = GetSkyLightColor();
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D gtexture;
	uniform sampler2D lightmap;

    uniform ivec2 eyeBrightnessSmooth;
    uniform float rainStrength;
    uniform float near;

    uniform vec3 skyColor;
    uniform vec3 fogColor;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogShape;
    uniform int fogMode;

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform float alphaTestRef;
    #endif
	
	#ifdef SHADOW_ENABLED
		uniform vec3 shadowLightPosition;

		#if SHADOW_TYPE != 0
	        uniform usampler2D shadowcolor0;
	        uniform sampler2D shadowtex0;

	        uniform float far;

	        #ifdef SHADOW_ENABLE_HWCOMP
	            #ifndef IS_OPTIFINE
	                uniform sampler2DShadow shadowtex1HW;
	                uniform sampler2D shadowtex1;
	            #else
	                uniform sampler2DShadow shadowtex1;
	            #endif
	        #else
	            uniform sampler2D shadowtex1;
	        #endif
			
			#if SHADOW_PCF_SAMPLES == 12
				#include "/lib/sampling/poisson_12.glsl"
			#elif SHADOW_PCF_SAMPLES == 24
				#include "/lib/sampling/poisson_24.glsl"
			#elif SHADOW_PCF_SAMPLES == 36
				#include "/lib/sampling/poisson_36.glsl"
			#endif

			#if SHADOW_TYPE == 3
				#include "/lib/shadows/csm.glsl"
				#include "/lib/shadows/csm_render.glsl"
			#else
				uniform mat4 shadowProjection;
				
				#include "/lib/shadows/basic.glsl"
	            #include "/lib/shadows/basic_render.glsl"
			#endif
	    #endif
	#endif

    #include "/lib/world/sky.glsl"
    #include "/lib/world/fog.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/basic_forward.glsl"


	void main() {
    /* DRAWBUFFERS:4 */
        gl_FragData[0] = BasicLighting();
	}
#endif
