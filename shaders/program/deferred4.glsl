#define RENDER_DEFERRED
#define RENDER_OPAQUE_FINAL

varying vec2 texcoord;

#ifdef SHADOW_ENABLED
    flat varying vec3 skyLightColor;
#endif

#ifdef RENDER_VERTEX
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;

    #include "/lib/world/sky.glsl"


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #ifdef SHADOW_ENABLED
            skyLightColor = GetSkyLightColor();
        #endif
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D colortex0;
    uniform sampler2D colortex1;
    uniform sampler2D colortex2;
    uniform sampler2D colortex3;
    uniform sampler2D colortex4;
    uniform sampler2D lightmap;
    uniform sampler2D depthtex0;

    #ifdef SSR_ENABLED
        uniform sampler2D colortex8;
    #endif

    #ifdef RSM_ENABLED
        uniform sampler2D colortex5;
    #endif

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelView;
    uniform int heldBlockLightValue;
    uniform float viewWidth;
    uniform float viewHeight;

    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform vec3 skyColor;

    #ifndef ATMOSPHERE_ENABLED
        uniform vec3 fogColor;
        uniform float fogStart;
        uniform float fogEnd;
    #endif

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;
    #endif


    #ifndef ATMOSPHERE_ENABLED
        #include "/lib/world/sky.glsl"
        #include "/lib/world/fog.glsl"
    #endif
    
    #include "/lib/sampling/linear.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/material.glsl"
    #include "/lib/lighting/material_reader.glsl"
    #include "/lib/lighting/hcm.glsl"
    #include "/lib/lighting/pbr.glsl"
    #include "/lib/ssr.glsl"
    #include "/lib/lighting/pbr_deferred.glsl"


	void main() {
        vec3 final = PbrLighting();

	/* DRAWBUFFERS:4 */
		gl_FragData[0] = vec4(final, 1.0);
	}
#endif
