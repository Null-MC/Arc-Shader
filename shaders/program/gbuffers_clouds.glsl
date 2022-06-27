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
	uniform sampler2D texture;


	void main() {
		vec4 colorMap = texture2D(texture, texcoord) * glcolor;
		vec4 normalMap = vec4(0.0);
		vec4 specularMap = vec4(0.0);
		vec4 lightingMap = vec4(0.0);

    /* DRAWBUFFERS:0123 */
        gl_FragData[0] = colorMap; //gcolor
        gl_FragData[1] = normalMap; //gdepth
        gl_FragData[2] = specularMap; //gnormal
        gl_FragData[3] = lightingMap; //composite
	}
#endif
