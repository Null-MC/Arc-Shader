#define RENDER_SKYBASIC

varying vec4 starData; //rgb = star color, a = flag for weather or not this pixel is a star.

#ifdef RENDER_VERTEX
	void main() {
		gl_Position = ftransform();
		starData = vec4(gl_Color.rgb, float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0));
	}
#endif

#ifdef RENDER_FRAG
	uniform float viewHeight;
	uniform float viewWidth;
	uniform mat4 gbufferModelView;
	uniform mat4 gbufferProjectionInverse;
	uniform vec3 fogColor;
	uniform vec3 skyColor;

	const float sunPathRotation = 30.0;

	float fogify(float x, float w) {
		return w / (x * x + w);
	}

	vec3 calcSkyColor(vec3 pos) {
		float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
		return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
	}


	void main() {
		vec3 color;
		if (starData.a > 0.5) {
			color = starData.rgb;
		}
		else {
			vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
			pos = gbufferProjectionInverse * pos;
			color = calcSkyColor(normalize(pos.xyz));
		}

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(color, 1.0); //gcolor
	}
#endif
