#extension GL_ARB_texture_query_levels : enable

#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

varying vec2 texcoord;
varying vec4 glcolor;
flat varying vec3 sunLightLum;
flat varying vec3 moonLightLum;

#ifdef RENDER_VERTEX
    flat out float exposure;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform int moonPhase;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
	    uniform ivec2 eyeBrightnessSmooth;
        uniform int heldBlockLightValue;
	#endif

    #include "/lib/lighting/blackbody.glsl"
	#include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		glcolor = gl_Color;

        exposure = GetExposure();

		vec2 skyLightLevels = GetSkyLightLevels();
		vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);
		sunLightLum = GetSunLightColor(skyLightTemp.x, skyLightLevels.x) * sunLumen;
		moonLightLum = GetMoonLightColor(skyLightTemp.y, skyLightLevels.y) * moonLumen;
	}
#endif

#ifdef RENDER_FRAG
    flat in float exposure;

	uniform sampler2D gtexture;

	uniform int renderStage;

	/* DRAWBUFFERS:46 */
	out vec4 outColor;

	#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
		out vec4 outLuminance;
	#endif


	void main() {
		vec4 color = texture2D(gtexture, texcoord) * glcolor;
		color.rgb = RGBToLinear(color.rgb);

		if (renderStage == MC_RENDER_STAGE_SUN) {
			color.rgb *= sunLightLum;

			// #ifdef ATMOSPHERE_ENABLED
			// 	color.a = 0.0;
			// #endif
		}
		else if (renderStage == MC_RENDER_STAGE_MOON) {
			color.rgb *= moonLightLum;
		}

		#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
			float lum = luminance(color.rgb) * color.a;
			outLuminance = vec4(log(lum + EPSILON), 0.0, 0.0, color.a);
		#endif

		color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
		outColor = color;
	}
#endif
