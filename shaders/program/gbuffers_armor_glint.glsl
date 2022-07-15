#define RENDER_ARMOR_GLINT

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#ifdef RENDER_VERTEX
	void main() {
		//use same transforms as entities and hand to avoid z-fighting issues
		gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D lightmap;
	uniform sampler2D gtexture;

	/* RENDERTARGETS: 0 */
	out vec4 outColor0;


	void main() {
		vec4 color = texture(gtexture, texcoord) * glcolor;
		color *= texture(lightmap, lmcoord);

		outColor0 = color;
	}
#endif
