#define RENDER_BASIC

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#ifdef RENDER_VERTEX
	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D lightmap;
	uniform sampler2D gtexture;


	void main() {
		vec4 color = texture(gtexture, texcoord) * glcolor;
		color *= texture(lightmap, lmcoord);

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = color; //gcolor
	}
#endif
