#define RENDER_GBUFFER
#define RENDER_CLOUDS

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
		vec4 colorMap = texture2D(gtexture, texcoord) * glcolor;
		//vec4 normalMap = vec4(0.0);
		//vec4 specularMap = vec4(0.0);
		//vec4 lightingMap = vec4(0.0);

		colorMap.rgb = RGBToLinear(colorMap.rgb);

    /* DRAWBUFFERS:4 */
        gl_FragData[0] = colorMap;
	}
#endif
