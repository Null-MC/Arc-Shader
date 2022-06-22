#extension GL_ARB_gpu_shader5 : enable

#define RENDER_WATER

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying float geoNoL;
varying mat3 matTBN;
varying vec3 tanViewPos;

#ifdef PARALLAX_ENABLED
    varying mat2 atlasBounds;
    varying vec2 localCoord;
#endif

#ifdef SHADOW_ENABLED
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;

    varying vec3 tanLightPos;
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
	in vec4 mc_Entity;
	in vec3 vaPosition;
    in vec4 at_tangent;
	in vec3 at_midBlock;

    #ifdef PARALLAX_ENABLED
        in vec4 mc_midTexCoord;
    #endif

	uniform mat4 gbufferModelView;
	uniform mat4 gbufferModelViewInverse;
	//uniform float frameTimeCounter;
	uniform vec3 cameraPosition;

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
    	uniform vec3 chunkOffset;
    #endif

	//#include "/lib/waving.glsl"

	#ifdef SHADOW_ENABLED
		uniform mat4 shadowModelView;
		uniform mat4 shadowProjection;
		uniform vec3 shadowLightPosition;
		uniform float far;

		#if SHADOW_TYPE == 3
            #ifdef IS_OPTIFINE
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

    #include "/lib/lighting/sky.glsl"
	//#include "/lib/lighting/basic_forward.glsl"
    //#include "/lib/lighting/pbr_forward.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/pbr.glsl"


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;

        mat3 matViewTBN;
        BasicVertex(matViewTBN);
        PbrVertex(matViewTBN);

        skyLightColor = GetSkyLightColor();
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D texture;
    uniform sampler2D normals;
    uniform sampler2D specular;
	uniform sampler2D lightmap;
    uniform sampler2D gcolor;

    // #if MC_VERSION >= 11700
    //     uniform float alphaTestRef;
    // #endif

    uniform int fogMode;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogShape;
    uniform vec3 fogColor;
    uniform vec3 skyColor;

	#if defined SHADOW_ENABLED && SHADOW_TYPE != 0
		uniform sampler2D shadowcolor0;
        uniform sampler2DShadow shadowtex0;
		uniform sampler2D shadowtex1;

        // #ifdef SHADOW_ENABLE_HWCOMP
        //     #if SHADOW_FILTER == 2
        //         uniform sampler2DShadow shadow;
        //         uniform sampler2D shadowtex0;
        //     #else
        //         uniform sampler2DShadow shadowtex0;
        //     #endif
        // #else
        //     uniform sampler2D shadowtex0;
        // #endif
		
		uniform vec3 shadowLightPosition;

		#if SHADOW_PCF_SAMPLES == 12
			#include "/lib/shadows/poisson_12.glsl"
		#elif SHADOW_PCF_SAMPLES == 24
			#include "/lib/shadows/poisson_24.glsl"
		#elif SHADOW_PCF_SAMPLES == 36
			#include "/lib/shadows/poisson_36.glsl"
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

    #ifdef PARALLAX_ENABLED
        uniform ivec2 atlasSize;

        #include "/lib/parallax.glsl"
    #endif

    #include "/lib/lighting/fog.glsl"
    #include "/lib/lighting/material.glsl"
    #include "/lib/lighting/material_reader.glsl"
	//#include "/lib/lighting/basic_forward.glsl"
    #include "/lib/lighting/pbr_forward.glsl"


	void main() {
        //float shadow;
        //vec4 colorMap, normalMap, specularMap, lightMap;
        //mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));

        vec4 final = PbrLighting();

        //lightMap = vec4(lmcoord, shadow, 0.0);

    /* DRAWBUFFERS:0 */
        gl_FragData[0] = final; //gcolor
        //gl_FragData[1] = normalMap; //gdepth
        //gl_FragData[2] = specularMap; //gnormal
        //gl_FragData[3] = lightMap; //composite
	}
#endif
