#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 BasicLighting() {
        float blockLight = lmcoord.x - (0.5/16.0) / (15.0/16.0);
        float skyLight = lmcoord.y - (0.5/16.0) / (15.0/16.0);

        blockLight *= blockLight;
        skyLight *= skyLight;

        vec4 albedo = texture2D(texture, texcoord) * glcolor;
        albedo.rgb = RGBToLinear(albedo.rgb);

        vec3 lightColor = skyLightColor;
        //float dark = skyLight * SHADOW_BRIGHTNESS * (31.0 / 32.0) + (1.0 / 32.0);

        #ifdef SHADOW_ENABLED
            if (geoNoL >= EPSILON && skyLight > EPSILON) {
                float shadow = GetShadowing(shadowPos);

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
        vec3 lmColor = RGBToLinear(texture2D(lightmap, lmCoord).rgb);

        vec4 final = albedo;

        final.rgb *= lmColor * lightColor;

        ApplyFog(final, viewPos);

        return final;
    }
#endif
