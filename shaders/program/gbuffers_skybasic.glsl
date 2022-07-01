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
	uniform float viewHeight;
	uniform float viewWidth;
	uniform mat4 gbufferModelView;
	uniform mat4 gbufferProjectionInverse;
	uniform vec3 fogColor;
	uniform vec3 skyColor;

	#ifdef ATMOSPHERE_ENABLED
		uniform mat4 gbufferModelViewInverse;
		uniform float eyeAltitude;
		uniform vec3 sunPosition;

		#include "/lib/world/atmosphere.glsl"
	#else
		float fogify(float x, float w) {
			return w / (x * x + w);
		}

		vec3 calcSkyColor(vec3 pos) {
			float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
			return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
		}
	#endif

	#include "/lib/tonemap.glsl"


	void main() {
		vec3 color;

		if (starData.a > 0.5) {
			color = RGBToLinear(starData.rgb);
		}
		else {
			vec3 viewPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0);
			viewPos = (gbufferProjectionInverse * vec4(viewPos, 1.0)).xyz;
			vec3 viewDir = normalize(viewPos);

			#ifndef ATMOSPHERE_ENABLED
				color = calcSkyColor(viewDir);
				color = RGBToLinear(color);
			#else
				vec3 localSunPos = mat3(gbufferModelViewInverse) * sunPosition.xyz;
				vec3 localSunDir = normalize(localSunPos);

				vec3 localViewPos = mat3(gbufferModelViewInverse) * viewPos.xyz;
				vec3 localViewDir = normalize(localViewPos);

				ScatteringParams setting;
				setting.sunRadius = 3000.0;
				setting.sunRadiance = 40.0;
				setting.mieG = 0.96;
				setting.mieHeight = 1200.0;
				setting.rayleighHeight = 8000.0;
				setting.earthRadius = 6360000.0;
				setting.earthAtmTopRadius = 6420000.0;
				setting.earthCenter = vec3(0.0, -6360000.0, 0.0);
				setting.waveLambdaMie = vec3(2e-7);
			    
			    // wavelength with 680nm, 550nm, 450nm
			    setting.waveLambdaRayleigh = ComputeWaveLambdaRayleigh(vec3(680e-9, 550e-9, 450e-9));
			    
			    // see https://www.shadertoy.com/view/MllBR2
				setting.waveLambdaOzone = vec3(1.36820899679147, 3.31405330400124, 0.13601728252538) * 0.6e-6 * 2.504;

				vec3 eye = vec3(0.0, 200.0 * eyeAltitude, 0.0);
			   	color = ComputeSkyInscattering(setting, eye, localViewDir, localSunDir).rgb;

			   	//color = localSunDir;
			#endif
		}

	    color = ApplyTonemap(color);

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(color, 1.0); //gcolor
	}
#endif
