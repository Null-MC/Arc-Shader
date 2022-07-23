#define RENDER_GBUFFER
#define RENDER_LINE

#ifdef RENDER_VERTEX
	out vec2 lmcoord;
	out vec2 texcoord;
	out vec4 glcolor;

	uniform mat4 gbufferModelView;
	uniform mat4 gbufferProjection;


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		glcolor = gl_Color;

		//gl_Position = ftransform();
		gl_Position = gbufferProjection * (gbufferModelView * gl_Vertex);
	}
#endif

#ifdef RENDER_FRAG
	in vec2 lmcoord;
	in vec2 texcoord;
	in vec4 glcolor;

	//uniform sampler2D lightmap;
	uniform sampler2D gtexture;

    /* RENDERTARGETS: 2 */


	void main() {
		vec4 colorMap = vec4(1000.0);//texture(gtexture, texcoord) * glcolor;
		vec4 normalMap = vec4(0.5, 0.5, 1.0, 0.0);
		vec4 specularMap = vec4(0.0);
		vec4 lightingMap = vec4(lmcoord, 1.0, 0.0);

        //outColor0.r = packUnorm4x8(colorMap);
        //outColor0.g = packUnorm4x8(normalMap);
        //outColor0.b = packUnorm4x8(specularMap);
        //outColor0.a = packUnorm4x8(lightingMap);
        gl_FragData[0] = vec4(1.0);
	}
#endif
