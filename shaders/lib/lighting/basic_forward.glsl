vec4 BasicLighting(const in LightData lightData) {
    vec4 albedo = texture(gtexture, texcoord);
    if (albedo.a < (0.5/255.0)) discard;

    //#if !defined RENDER_TEXTURED && !defined RENDER_WEATHER
    //    if (albedo.a < alphaTestRef) discard;
    //#endif

    albedo.rgb = RGBToLinear(albedo.rgb * glcolor.rgb);
    albedo.a *= PARTICLE_OPACITY;

    float shadow = step(EPSILON, lightData.geoNoL);
    shadow *= step(1.0 / 32.0, lightData.skyLight);

    vec3 skyAmbient = vec3(pow(lightData.skyLight, 5.0));
    #ifdef SKY_ENABLED
        float skyLight2 = pow2(lightData.skyLight);
        float ambientBrightness = mix(0.36 * skyLight2, 0.95 * lightData.skyLight, rainStrength); // SHADOW_BRIGHTNESS
        skyAmbient *= GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;
    #endif

    float blockAmbient = pow(lightData.blockLight, 5.0) * BlockLightLux;
    vec3 ambient = 0.1 + blockAmbient + skyAmbient;
    vec3 diffuse = vec3(0.0);

    vec3 shadowColor = vec3(1.0);
    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if defined SHADOW_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER)
            if (shadow > EPSILON) {
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    shadow *= GetShadowing(lightData);
                #else
                    shadow *= GetShadowing(lightData);
                #endif

                skyLight = max(skyLight, shadow);
            }

            #ifdef SHADOW_COLOR
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    shadowColor = GetShadowColor(lightData);
                #else
                    shadowColor = GetShadowColor(lightData);
                #endif
            #endif
        #endif
    #else
        shadow = glcolor.a;
    #endif

    #ifdef SKY_ENABLED
        vec3 skyLightColor = lightData.sunTransmittance * GetSunLux() + moonColor;
        diffuse += albedo.rgb * skyLightColor * shadowColor * shadow;
    #endif

    #if defined HANDLIGHT_ENABLED && !defined RENDER_HAND && !defined RENDER_HAND_WATER
        if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
            const float roughL = 1.0;
            const float scattering = 0.0;
            diffuse += ApplyHandLighting(albedo.rgb, viewPos.xyz);
        }
    #endif

    vec4 final = albedo;
    final.rgb *= ambient;
    final.rgb += diffuse;

    float fogFactor = ApplyFog(final, viewPos, lightData, EPSILON);

    #ifdef SKY_ENABLED
        vec3 viewDir = normalize(viewPos);
        float vlScatter = GetScatteringFactor(lightData.skyLightLevels.x);

        vec3 sunDir = normalize(sunPosition);
        float sun_VoL = dot(viewDir, sunDir);
        float sunScattering = ComputeVolumetricScattering(sun_VoL, vlScatter);
        vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux(); // * sunColor

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        float moonScattering = ComputeVolumetricScattering(moon_VoL, vlScatter);

        vec3 vlColor =
            max(sunScattering, 0.0) * sunColorFinal +
            max(moonScattering, 0.0) * moonColor;

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && defined VL_ENABLED && (defined VL_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER))
            mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
            vec3 shadowViewStart = (matViewToShadowView * vec4(vec3(0.0, 0.0, -near), 1.0)).xyz;
            vec3 shadowViewEnd = (matViewToShadowView * vec4(viewPos, 1.0)).xyz;

            #ifdef SHADOW_COLOR
                vlColor *= GetVolumetricLightingColor(lightData, shadowViewStart, shadowViewEnd);
            #else
                vlColor *= GetVolumetricLighting(lightData, shadowViewStart, shadowViewEnd);
            #endif
        #else
            vlColor *= fogFactor;
        #endif

        if (isEyeInWater == 1) vlColor *= WATER_SCATTER_COLOR.rgb;
        final.rgb += vlColor * (0.01 * VL_STRENGTH);
    #endif

    return final;
}
