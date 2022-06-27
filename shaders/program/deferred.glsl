#define RENDER_DEFERRED

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
    uniform sampler2D lightmap;
    uniform sampler2D depthtex0;

    #ifdef SSR_ENABLED
        uniform sampler2D colortex4;
    #endif

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelView;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform int heldBlockLightValue;

    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform vec3 skyColor;

    uniform int fogMode;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogShape;
    uniform vec3 fogColor;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;
    #endif

    #include "/lib/tonemap.glsl"
    #include "/lib/world/fog.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/lighting/material.glsl"
    #include "/lib/lighting/material_reader.glsl"
    #include "/lib/lighting/hcm.glsl"
    #include "/lib/lighting/pbr.glsl"
    #include "/lib/ssr.glsl"
    #include "/lib/lighting/pbr_deferred.glsl"


	void main() {
        vec3 final = PbrLighting();

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(final, 1.0); //gcolor
	}
#endif
