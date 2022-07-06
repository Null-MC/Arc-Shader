#define RENDER_GBUFFER
#define RENDER_SKYBASIC

varying vec4 starData; //rgb = star color, a = flag for weather or not this pixel is a star.

#ifdef RENDER_VERTEX
	void main() {
		gl_Position = ftransform();
		starData = vec4(gl_Color.rgb, float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0));
	}
#endif

#ifdef RENDER_FRAG
	uniform mat4 gbufferModelView;
	uniform mat4 gbufferProjectionInverse;
	uniform float viewWidth;
	uniform float viewHeight;
	uniform vec3 fogColor;
	uniform vec3 skyColor;


	float fogify(float x, float w) {
		return w / (x * x + w);
	}

	vec3 calcSkyColor(vec3 pos) {
		float upDot = dot(pos, gbufferModelView[1].xyz);
		return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
	}

	void main() {
		vec3 clipPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0);
		vec4 viewPos = gbufferProjectionInverse * vec4(clipPos, 1.0);
		viewPos.xyz /= viewPos.w;

		vec3 viewDir = normalize(viewPos.xyz);
		vec3 color = calcSkyColor(viewDir);
		color = RGBToLinear(color);

		color += RGBToLinear(starData.rgb) * starData.a * 10.0;

	/* DRAWBUFFERS:4 */
		gl_FragData[0] = vec4(color, 1.0);
	}
#endif
