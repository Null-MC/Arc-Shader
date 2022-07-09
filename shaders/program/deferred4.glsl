#extension GL_EXT_gpu_shader4 : enable

#define RENDER_DEFERRED
#define RENDER_OPAQUE_FINAL

#ifdef RENDER_VERTEX
    out vec2 texcoord;

    #ifdef SHADOW_ENABLED
        flat out vec3 skyLightColor;
    #endif

    uniform float rainStrength;
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
    in vec2 texcoord;

    #ifdef SHADOW_ENABLED
        flat in vec3 skyLightColor;
    #endif

	uniform sampler2D BUFFER_COLOR;
    uniform sampler2D BUFFER_NORMAL;
    uniform sampler2D BUFFER_SPECULAR;
    uniform sampler2D BUFFER_LIGHTING;
    uniform sampler2D BUFFER_HDR;
    uniform sampler2D lightmap;
    uniform sampler2D depthtex0;

    #ifdef SSR_ENABLED
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #ifdef RSM_ENABLED
        uniform sampler2D BUFFER_RSM_COLOR;
    #endif

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelView;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float near;
    
    uniform ivec2 eyeBrightnessSmooth;
    uniform int heldBlockLightValue;

    uniform float rainStrength;
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

        final = clamp(final, vec3(0.0), vec3(1000.0));

	/* DRAWBUFFERS:4 */
		gl_FragData[0] = vec4(final, 1.0);
	}
#endif
