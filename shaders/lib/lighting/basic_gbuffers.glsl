#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    void BasicLighting(const in mat2 dFdXY, out vec4 colorMap) {
        colorMap = textureGrad(gtexture, texcoord, dFdXY[0], dFdXY[1]) * glcolor;

        #if defined RENDER_TEXTURED || defined RENDER_WEATHER
            //colorMap *= glcolor;

            float threshold = InterleavedGradientNoise(gl_FragCoord.xy);
            if (colorMap.a <= threshold) {discard; return;}
        #else
            if (colorMap.a < alphaTestRef) {discard; return;}

            //colorMap.rgb *= glcolor.rgb;
        #endif

        colorMap.a = 1.0;        
    }
#endif
