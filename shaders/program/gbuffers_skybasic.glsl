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
	uniform float viewHeight;
	uniform float viewWidth;
	uniform vec3 fogColor;
	uniform vec3 skyColor;

	//#include "/lib/tonemap.glsl"


	float fogify(float x, float w) {
		return w / (x * x + w);
	}

	vec3 calcSkyColor(vec3 pos) {
		float upDot = dot(pos, gbufferModelView[1].xyz);
		return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
	}

	void main() {
		vec3 color;

		if (starData.a > 0.5) {
			color = starData.rgb;
		}
		else {
			vec3 viewPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0);
			viewPos = (gbufferProjectionInverse * vec4(viewPos, 1.0)).xyz;
			vec3 viewDir = normalize(viewPos);

			color = calcSkyColor(viewDir);
			color = color;
		}

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(color, 1.0);
	}
#endif
