#define RENDER_GBUFFER
#define RENDER_WEATHER

varying vec2 texcoord;
varying vec4 glcolor;

#ifdef RENDER_VERTEX
	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		glcolor = gl_Color;
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D gtexture;

	void main() {
		vec4 color = texture2D(gtexture, texcoord) * glcolor;

	/* DRAWBUFFERS:4 */
		gl_FragData[0] = color;
	}
#endif
