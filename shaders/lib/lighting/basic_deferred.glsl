#ifdef RENDER_VERTEX
    // vec3 GetSkyLightColor() {
    //     vec3 sunDir = normalize(sunPosition);
    //     vec3 moonDir = normalize(moonPosition);
    //     vec3 upDir = normalize(upPosition);
    //     float sun_UoL = dot(upDir, sunDir);
    //     float moon_UoL = dot(upDir, moonDir);

    //     vec3 sunColor = vec3(2.0) * max(sun_UoL, 0.0);
    //     vec3 moonColor = vec3(0.1) * max(moon_UoL, 0.0);
    //     return sunColor + moonColor;
    // }

	void BasicVertex() {
		vec4 pos = gl_Vertex;

		#if defined RENDER_TERRAIN && defined ENABLE_WAVING
			if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
				pos.xyz += GetWavingOffset();
		#endif

		vec4 viewPos = gl_ModelViewMatrix * pos;

		viewPos = viewPos.xyz;// / viewPos.w;

		#ifdef RENDER_TEXTURED
			// TODO: extract billboard direction from view matrix?
			vNormal = normalize(gl_NormalMatrix * gl_Normal);
		#else
			vNormal = normalize(gl_NormalMatrix * gl_Normal);
		#endif

        #if defined PARALLAX_ENABLED && !defined RENDER_TEXTURED
            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            vec2 vCoord = sign(coordNMid) * 0.5 + 0.5;
        #endif

        #ifdef SHADOW_ENABLED
            #ifdef RENDER_TEXTURED
                geoNoL = 1.0;
            #else
                vec3 lightDir = normalize(shadowLightPosition);
                geoNoL = dot(lightDir, vNormal);
            #endif

            #ifdef RENDER_SHADOW
                ApplyShadows(viewPos);
            #endif
        #else
            geoNoL = 1.0;
        #endif

		gl_Position = gl_ProjectionMatrix * viewPos;

        //skyLightColor = GetSkyLightColor();
        skyLightColor = GetSkyLightLuminance();

        blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;
	}
#endif

#ifdef RENDER_FRAG
 //    #if MC_VERSION >= 11700
 //    	uniform float alphaTestRef;
 //    #endif

	// uniform float screenBrightness;
	// uniform vec3 upPosition;

	// uniform int fogMode;
	// uniform float fogStart;
	// uniform float fogEnd;
	// uniform int fogShape;
	// uniform vec3 fogColor;
	// uniform vec3 skyColor;


	// vec4 ApplyLighting(const in vec4 albedo, const in vec3 lightColor, const in vec2 lm) {
	// 	vec3 lmValue = texture(lightmap, lm).rgb * screenBrightness;
	// 	lmValue = RGBToLinear(lmValue);
	// 	vec4 final = albedo;

	// 	#if LIGHTING_TYPE == 1 || LIGHTING_TYPE == 2
	// 		// [1] Phong & [2] Blinn-Phong
	// 		vec3 normal = normalize(vNormal);
	// 		vec3 viewDir = normalize(-viewPos);
	// 		vec3 lightDir = normalize(shadowLightPosition);

	// 		float specular;
	// 		#if LIGHTING_TYPE == 2
	// 			// Blinn-Phong
	// 			vec3 halfDir = normalize(lightDir + viewDir);
	// 			float specAngle = max(dot(halfDir, normal), 0.0);
	// 			specular = pow(specAngle, shininess);
	// 		#else
	// 			// Phong
	// 			vec3 reflectDir = reflect(-lightDir, normal);
	// 			float specAngle = max(dot(reflectDir, viewDir), 0.0);
	// 			specular = pow(specAngle, shininess * 0.25);
	// 		#endif

	// 		vec3 ambientColor = lmValue * SHADOW_BRIGHTNESS;

	// 		final.rgb *= ambientColor + lightColor * (geoNoL + specular);
	// 	#else
	// 		// [0] None
	// 		final.rgb *= lmValue * lightColor;
	// 	#endif

	// 	return final;
	// }

    vec4 BasicLighting() {
        float blockLight = lmcoord.x - (0.5/16.0) / (15.0/16.0);
        float skyLight = lmcoord.y - (0.5/16.0) / (15.0/16.0);

        blockLight *= blockLight;
        skyLight *= skyLight;

        vec4 albedo = texture(gtexture, texcoord) * glcolor;
        albedo.rgb = RGBToLinear(albedo.rgb);

        vec3 lightColor = skyLightColor;
        //float dark = skyLight * SHADOW_BRIGHTNESS * (31.0 / 32.0) + (1.0 / 32.0);

        #ifdef SHADOW_ENABLED
            if (geoNoL >= EPSILON && skyLight > EPSILON) {
                float shadow = GetShadowing();

                #if SHADOW_COLORS == 1
                    vec3 shadowColor = GetShadowColor();

                    shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    //also make colors less intense when the block light level is high.
                    shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    lightColor *= shadowColor;
                #endif

                //surface is in direct sunlight. increase light level.
                // #ifdef RENDER_TEXTURED
                //     float lightMax = 1.0;
                // #else
                //     float lightMax = mix(dark, 31.0 / 32.0, sqrt(geoNoL));
                // #endif

                skyLight = max(0.0, shadow);
                //skyLight = mix(dark, lightMax, shadow);
            }
            else {
                skyLight = 0.0;
            }
        #endif
        
        vec2 lmCoord = vec2(blockLight, skyLight) * (15.0/16.0) + (0.5/16.0);
        vec3 lmColor = RGBToLinear(texture(lightmap, lmCoord).rgb);

        vec4 final = albedo;

        final.rgb *= lmColor * lightColor;

        ApplyFog(final, viewPos);

        return final;
    }
#endif
