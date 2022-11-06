vec4 BasicLighting(const in LightData lightData) {
    vec4 albedo = texture(gtexture, texcoord);
    if (albedo.a < (0.5/255.0)) discard;

    //#if !defined RENDER_TEXTURED && !defined RENDER_WEATHER
    //    if (albedo.a < alphaTestRef) discard;
    //#endif

    albedo.rgb = RGBToLinear(albedo.rgb * glcolor.rgb);

    #ifdef RENDER_TEXTURED
        albedo.a *= PARTICLE_OPACITY;
    #else
        albedo.a *= WEATHER_OPACITY * 0.01;
    #endif

    float shadow = step(EPSILON, lightData.geoNoL);
    //shadow *= step(1.0 / 32.0, lightData.skyLight);

    float skyLight = lightData.skyLight;
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

    #ifdef LIGHTLEAK_FIX
        // Make areas without skylight fully shadowed (light leak fix)
        float lightLeakFix = step(skyLight, EPSILON);
        shadow *= lightLeakFix;
    #endif

    float skyLight2 = pow2(skyLight);
    float skyLight3 = pow3(skyLight);

    vec3 ambient = vec3(MinWorldLux);
    vec3 diffuse = albedo.rgb * pow5(lightData.blockLight) * blockLightColor;

    //vec3 skyAmbient = vec3(pow(skyLight, 5.0));
    #ifdef SKY_ENABLED
        float ambientBrightness = mix(0.8 * skyLight2, 0.95 * skyLight, rainStrength);// * SHADOW_BRIGHTNESS;
        ambient += GetSkyAmbientLight(lightData, viewNormal) * ambientBrightness;

        vec3 skyLightColor = lightData.sunTransmittance * GetSunLux() + moonColor;
        diffuse += albedo.rgb * skyLightColor * shadowColor * shadow *skyLight3;
    #endif

    #if defined HANDLIGHT_ENABLED && !defined RENDER_HAND && !defined RENDER_HAND_WATER
        if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
            //const float roughL = 1.0;
            //const float scattering = 0.0;
            diffuse += ApplyHandLighting(albedo.rgb, viewPos.xyz);
        }
    #endif

    vec4 final = albedo;
    final.rgb *= ambient * SHADOW_BRIGHTNESS;
    final.rgb += diffuse;

    vec3 viewDir = normalize(viewPos);

    #ifdef RENDER_WEATHER
        vec3 sunDir = normalize(sunPosition);
        float sun_VoL = dot(viewDir, sunDir);
        vec3 sunLightColor = 3.0 * lightData.sunTransmittanceEye * GetSunLux(); // * sunColor;
        float rainSnowSunVL = ComputeVolumetricScattering(sun_VoL, 0.88);

        vec3 moonDir = normalize(moonPosition);
        float moon_VoL = dot(viewDir, moonDir);
        float rainSnowMoonVL = ComputeVolumetricScattering(moon_VoL, 0.74);

        final.rgb += albedo.rgb * (max(rainSnowSunVL, 0.0) * sunLightColor + max(rainSnowMoonVL, 0.0) * 20.0*moonColor) * shadow;
        final.a = albedo.a * mix(WEATHER_OPACITY * 0.01, 1.0, saturate(max(rainSnowSunVL, rainSnowMoonVL)));
    #endif

    //float fogFactor = ApplyFog(final, viewPos, lightData, EPSILON);
    float fogFactor;
    vec3 fogColorFinal;
    GetFog(lightData, viewPos, fogColorFinal, fogFactor);

    ApplyFog(final, fogColorFinal, fogFactor, 1.0/255.0);

    #ifdef SKY_ENABLED
        vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux(); // * sunColor
        vec3 vlColor = GetVanillaSkyScattering(viewDir, lightData.skyLightLevels, sunColorFinal, moonColor);

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && defined VL_ENABLED && (defined VL_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER))
            // mat4 matViewToShadowView = shadowModelView * gbufferModelViewInverse;
            // vec3 shadowViewStart = (matViewToShadowView * vec4(vec3(0.0, 0.0, -near), 1.0)).xyz;
            // vec3 shadowViewEnd = (matViewToShadowView * vec4(viewPos, 1.0)).xyz;
            vec3 viewNear = viewDir * near;

            #ifdef SHADOW_COLOR
                vlColor *= GetVolumetricLightingColor(lightData, viewNear, viewPos);
            #else
                vlColor *= GetVolumetricLighting(lightData, viewNear, viewPos);
            #endif
        #else
            vlColor *= fogFactor;
        #endif

        final.rgb += vlColor;
    #endif

    return final;
}
