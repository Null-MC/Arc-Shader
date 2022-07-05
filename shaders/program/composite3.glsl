#define RENDER_COMPOSITE
#define RENDER_COMPOSITE_BLOOM_BLUR
//#define RENDER_COMPOSITE_BLOOM_BLUR_V

varying vec2 texcoord;

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex7;

    uniform float viewWidth;
    uniform float viewHeight;

    #include "/lib/bloom.glsl"


    void main() {
        float tileMin, tileMax;
        int tile = GetBloomTileIndex(tileMin, tileMax);

        //float pixelSize = 1.0 / viewHeight;

        vec3 final = vec3(0.0);

        if (tile >= 0) {
            //float tileSize = tileMax - tileMin;
            vec2 tileRes = vec2(viewWidth, viewHeight);

            final = BloomBlur13(texcoord, tileRes, vec2(0.0, 1.0));
        }

    /* DRAWBUFFERS:7 */
        gl_FragData[0] = vec4(final, 1.0);
    }
#endif
