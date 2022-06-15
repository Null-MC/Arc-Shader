#ifdef RENDER_VERTEX
	void BasicVertex() {
		vec4 pos = gl_Vertex;

		#if defined RENDER_TERRAIN && defined ENABLE_WAVING
			if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
				pos.xyz += GetWavingOffset();
		#endif

		vec4 viewPos = gl_ModelViewMatrix * pos;

		vPos = viewPos.xyz;// / viewPos.w;

		#ifdef RENDER_TEXTURED
			// TODO: extract billboard direction from view matrix?
			vNormal = normalize(gl_NormalMatrix * gl_Normal);
		#else
			vNormal = normalize(gl_NormalMatrix * gl_Normal);
		#endif

		#ifndef WORLD_END
			#ifdef RENDER_TEXTURED
				geoNoL = 1.0;
			#else
				vec3 lightDir = normalize(shadowLightPosition);
				geoNoL = dot(lightDir, vNormal);

				// #if defined RENDER_TERRAIN && defined SHADOW_EXCLUDE_FOLIAGE
				// 	//when SHADOW_EXCLUDE_FOLIAGE is enabled, act as if foliage is always facing towards the sun.
				// 	//in other words, don't darken the back side of it unless something else is casting a shadow on it.
				// 	if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) geoNoL = 1.0;
				// #endif
			#endif

			#if SHADOW_TYPE != 0 && !defined RENDER_SHADOW && !defined WORLD_END
				ApplyShadows(viewPos);
			#endif
		#else
			geoNoL = 1.0;
		#endif

		gl_Position = gl_ProjectionMatrix * viewPos;
	}
#endif

#ifdef RENDER_FRAG
	const float shininess = 16.0;

	uniform float alphaTestRef;
	uniform float screenBrightness;
	uniform vec3 upPosition;

	uniform int fogMode;
	uniform float fogStart;
	uniform float fogEnd;
	uniform int fogShape;
	uniform vec3 fogColor;
	uniform vec3 skyColor;


	vec4 ApplyLighting(const in vec4 albedo, const in vec3 lightColor, const in vec2 lm) {
		vec3 lmValue = texture2D(lightmap, lm).rgb * screenBrightness;
		lmValue = RGBToLinear(lmValue);
		vec4 final = albedo;

		#if LIGHTING_TYPE == 1 || LIGHTING_TYPE == 2
			// [1] Phong & [2] Blinn-Phong
			vec3 normal = normalize(vNormal);
			vec3 viewDir = normalize(-vPos);
			vec3 lightDir = normalize(shadowLightPosition);

			float specular;
			#if LIGHTING_TYPE == 2
				// Blinn-Phong
				vec3 halfDir = normalize(lightDir + viewDir);
				float specAngle = max(dot(halfDir, normal), 0.0);
				specular = pow(specAngle, shininess);
			#else
				// Phong
				vec3 reflectDir = reflect(-lightDir, normal);
				float specAngle = max(dot(reflectDir, viewDir), 0.0);
				specular = pow(specAngle, shininess * 0.25);
			#endif

			vec3 ambientColor = lmValue * SHADOW_BRIGHTNESS;

			final.rgb *= ambientColor + lightColor * (geoNoL + specular);
		#else
			// [0] None
			final.rgb *= lmValue * lightColor;
		#endif

		return final;
	}

	void ApplyFog(inout vec4 color) {
		vec3 fogPos = vPos;
		//if (fogShape == 1) fogPos.z = 0.0;
		float fogF = clamp((length(fogPos) - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

		vec3 fogCol = RGBToLinear(fogColor);
		color.rgb = mix(color.rgb, fogCol, fogF);

		if (color.a > alphaTestRef)
			color.a = mix(color.a, 1.0, fogF);
	}

	vec4 BasicLighting() {
		vec4 texColor = texture2D(texture, texcoord) * glcolor;
		vec3 lightColor = vec3(1.0);
		vec2 lm = lmcoord;

		vec4 albedo = texColor;
		albedo.rgb = RGBToLinear(albedo.rgb);

		float dark = lm.y * SHADOW_BRIGHTNESS * (31.0 / 32.0) + (1.0 / 32.0);

		if (geoNoL >= EPSILON && lm.y > 1.0/32.0) {
			#if SHADOW_TYPE != 0 && !defined WORLD_END
				float shadow = GetShadowing();

				#if SHADOW_COLORS == 1
					vec3 shadowColor = GetShadowColor();

					shadowColor = mix(vec3(1.0), shadowColor, shadow);

					//also make colors less intense when the block light level is high.
					shadowColor = mix(shadowColor, vec3(1.0), lm.x);

					lightColor *= shadowColor;
				#endif

				//surface is in direct sunlight. increase light level.
				#ifdef RENDER_TEXTURED
					float lightMax = 31.0 / 32.0;
				#else
					float lightMax = mix(dark, 31.0 / 32.0, sqrt(geoNoL));
				#endif

				lightMax = max(lightMax, lm.y);
				lm.y = mix(dark, lightMax, shadow);
			#else
				#ifdef RENDER_TEXTURED
					lm.y = 31.0 / 32.0;
				#else
					lm.y = mix(dark, 31.0 / 32.0, sqrt(geoNoL));
				#endif
			#endif
		}
		else {
			lm.y = dark;
		}

		return ApplyLighting(albedo, lightColor, lm);
	}
#endif
