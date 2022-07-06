#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

varying vec2 texcoord;
varying vec4 glcolor;
flat varying vec2 skyLightIntensity;

#ifdef RENDER_VERTEX
    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;

	#include "/lib/world/sky.glsl"


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		glcolor = gl_Color;

		skyLightIntensity = GetSkyLightIntensity();
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D gtexture;

	uniform int renderStage;


	void main() {
		vec4 color = texture2D(gtexture, texcoord) * glcolor;
		color.rgb = RGBToLinear(color.rgb);

		if (renderStage == MC_RENDER_STAGE_SUN) {
			color.rgb *= skyLightIntensity.x * 10.0;
		}
		else if (renderStage == MC_RENDER_STAGE_MOON) {
			color.rgb *= skyLightIntensity.y * 20.0;
		}

	/* DRAWBUFFERS:4 */
		gl_FragData[0] = color; //gcolor
	}
#endif
