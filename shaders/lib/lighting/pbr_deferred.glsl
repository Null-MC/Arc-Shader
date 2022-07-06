//#define ALLOW_TEXELFETCH

#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec3 PbrLighting() {
        ivec2 iTex = ivec2(texcoord * vec2(viewWidth, viewHeight));
        float screenDepth = texelFetch(depthtex0, iTex, 0).r;

        // SKY
        if (screenDepth == 1.0) {
            //discard;
            //return vec4(vec3(1.0), 0.0);
            return texelFetch(colortex4, iTex, 0).rgb;
        }

        vec3 colorMap = texelFetch(colortex0, iTex, 0).rgb;
        vec4 normalMap = texelFetch(colortex1, iTex, 0);
        vec4 specularMap = texelFetch(colortex2, iTex, 0);
        vec4 lightingMap = texelFetch(colortex3, iTex, 0);

        vec3 clipPos = vec3(texcoord, screenDepth) * 2.0 - 1.0;
        vec4 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0));
        viewPos.xyz /= viewPos.w;

        PbrMaterial material = PopulateMaterial(colorMap, normalMap, specularMap);

        return PbrLighting2(material, lightingMap.xy, lightingMap.b, lightingMap.a, viewPos.xyz).rgb;
    }
#endif
