#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

varying vec2 texcoord;
varying vec4 glcolor;
flat varying vec3 sunLightLum;
flat varying vec3 moonLightLum;
//flat varying vec2 skyLightIntensity;

#ifdef RENDER_VERTEX
    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;

    #include "/lib/lighting/blackbody.glsl"
	#include "/lib/world/sky.glsl"


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		glcolor = gl_Color;

		//skyLightIntensity = GetSkyLightIntensity();
		vec2 skyLightLevels = GetSkyLightLevels();
		vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);
		sunLightLum = GetSunLightLuminance(skyLightTemp.x, skyLightLevels.x);
		moonLightLum = GetMoonLightLuminance(skyLightTemp.y, skyLightLevels.y);
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D gtexture;

	uniform int renderStage;


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

		//color.rgb = clamp(color.rgb, vec3(0.0), vec3(65000));

	/* DRAWBUFFERS:4 */
		gl_FragData[0] = color; //gcolor
	}
#endif
