#define RENDER_FINAL

#ifdef RENDER_VERTEX
	out vec2 texcoord;


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D colortex4;

	in vec2 texcoord;


	void main() {
		vec3 color = texture2D(colortex4, texcoord).rgb;

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(color, 1.0); //gcolor
	}
#endif
