#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 BasicLighting() {
        vec4 albedo = texture(gtexture, texcoord);

        #if !defined RENDER_TEXTURED && !defined RENDER_WEATHER
            if (albedo.a < alphaTestRef) discard;
        #endif

        albedo *= glcolor;
        albedo.rgb = RGBToLinear(albedo.rgb);

        float blockLight = clamp((lmcoord.x - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
        float skyLight = clamp((lmcoord.y - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);

        //blockLight = blockLight*blockLight*blockLight;
        //skyLight = skyLight*skyLight*skyLight;

        float shadow = step(EPSILON, geoNoL) * step(1.0 / 32.0, skyLight);
        //vec3 lightColor = skyLightColor;

        vec3 skyAmbient = GetSkyAmbientLight(viewNormal) * pow(skyLight, 5.0);
        float blockAmbient = pow(blockLight, 5.0) * BlockLightLux;

        vec3 ambient = 0.1 + blockAmbient + skyAmbient;

        #if defined SHADOW_ENABLED && SHADOW_TYPE != 0
            if (shadow > EPSILON) {
                shadow = GetShadowing(shadowPos);

                // #if SHADOW_COLORS == 1
                //     vec3 shadowColor = GetShadowColor();

                //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                //     //also make colors less intense when the block light level is high.
                //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                //     lightColor *= shadowColor;
                // #endif

                skyLight = max(skyLight, shadow);
            }
        #endif
        
        //vec2 lmCoord = vec2(blockLight, skyLight) * (15.0/16.0) + (0.5/16.0);
        //vec3 lmColor = RGBToLinear(texture(lightmap, lmCoord).rgb);

        vec4 final = albedo;
        final.rgb *= (ambient + skyLightColor * shadow);

        ApplyFog(final, viewPos, skyLight, EPSILON);

        return final;
    }
#endif
