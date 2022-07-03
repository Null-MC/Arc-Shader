//#define ALLOW_TEXELFETCH

#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec3 PbrLighting() {
        #ifdef ALLOW_TEXELFETCH
            ivec2 iTex = ivec2(texcoord * vec2(viewWidth, viewHeight));
            vec3 colorMap = texelFetch(colortex0, iTex, 0).rgb;
            float screenDepth = texelFetch(depthtex0, iTex, 0).r;
        #else
            vec3 colorMap = texture2DLod(colortex0, texcoord, 0).rgb;
            float screenDepth = texture2DLod(depthtex0, texcoord, 0).r;
        #endif

        // SKY
        if (screenDepth == 1.0) return colorMap;

        #ifdef ALLOW_TEXELFETCH
            vec4 normalMap = texelFetch(colortex1, iTex, 0);
            vec4 specularMap = texelFetch(colortex2, iTex, 0);
            vec4 lightingMap = texelFetch(colortex3, iTex, 0);
        #else
            vec4 normalMap = texture2DLod(colortex1, texcoord, 0);
            vec4 specularMap = texture2DLod(colortex2, texcoord, 0);
            vec4 lightingMap = texture2DLod(colortex3, texcoord, 0);
        #endif

        vec3 clipPos = vec3(texcoord, screenDepth) * 2.0 - 1.0;
        vec4 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0));
        viewPos.xyz /= viewPos.w;

        PbrMaterial material = PopulateMaterial(colorMap, normalMap, specularMap);

        return PbrLighting2(material, lightingMap.xy, lightingMap.b, lightingMap.a, viewPos.xyz).rgb;
    }
#endif
