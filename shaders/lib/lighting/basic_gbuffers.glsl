#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    void BasicLighting(const in mat2 dFdXY, out vec4 colorMap) {
        colorMap = textureGrad(gtexture, texcoord, dFdXY[0], dFdXY[1]);
        if (colorMap.a < alphaTestRef) discard;

        colorMap.rgb *= glcolor.rgb;
        colorMap.a = 1.0;        
    }
#endif
