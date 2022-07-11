//#define ALLOW_TEXELFETCH

#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 PbrLighting() {
        ivec2 iTex = ivec2(texcoord * vec2(viewWidth, viewHeight));
        float screenDepth = texelFetch(depthtex0, iTex, 0).r;

        // SKY
        if (screenDepth == 1.0) {
            //discard;
            //return vec4(vec3(1.0), 0.0);
            vec3 skyColor = texelFetch(BUFFER_HDR, iTex, 0).rgb;
            return vec4(skyColor, 0.0);
        }

        vec3 colorMap = texelFetch(BUFFER_COLOR, iTex, 0).rgb;
        vec4 normalMap = texelFetch(BUFFER_NORMAL, iTex, 0);
        vec4 specularMap = texelFetch(BUFFER_SPECULAR, iTex, 0);
        vec4 lightingMap = texelFetch(BUFFER_LIGHTING, iTex, 0);

        vec3 clipPos = vec3(texcoord, screenDepth) * 2.0 - 1.0;
        vec4 viewPos = gbufferProjectionInverse * vec4(clipPos, 1.0);
        viewPos.xyz /= viewPos.w;

        PbrMaterial material = PopulateMaterial(colorMap, normalMap, specularMap);

        vec3 final = PbrLighting2(material, lightingMap.xy, lightingMap.b, lightingMap.a, viewPos.xyz).rgb;

        return vec4(final, 1.0);
    }
#endif
