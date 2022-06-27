#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 BasicLighting() {
        vec4 albedo = texture2D(texture, texcoord);

        #ifndef RENDER_TEXTURED
            if (albedo.a < alphaTestRef) discard;
        #endif

        albedo *= glcolor;
        albedo.rgb = RGBToLinear(albedo.rgb);

        float blockLight = (lmcoord.x - (0.5/16.0)) / (15.0/16.0);
        float skyLight = (lmcoord.y - (0.5/16.0)) / (15.0/16.0);

        blockLight = blockLight*blockLight*blockLight;
        skyLight = skyLight*skyLight*skyLight;

        float shadow = step(EPSILON, geoNoL) * step(1.0 / 32.0, skyLight);
        vec3 lightColor = skyLightColor;

        vec3 skyAmbient = SHADOW_BRIGHTNESS * GetSkyAmbientColor(viewNormal) * (0.1 + 0.9 * skyLight);
        vec3 blockAmbient = max(vec3(blockLight), skyAmbient);

        #ifdef SHADOW_ENABLED
            if (shadow > EPSILON) {
                float lightSSS = 0.0;
                shadow = GetShadowing(shadowPos, lightSSS);

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
        //vec3 lmColor = RGBToLinear(texture2D(lightmap, lmCoord).rgb);

        vec4 final = albedo;
        final.rgb *= (minLight + blockAmbient + lightColor * shadow);

        ApplyFog(final, viewPos, skyLight, EPSILON);

        return final;
    }
#endif
