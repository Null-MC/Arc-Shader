#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE
#define RENDER_COMPOSITE_BLOOM_BLUR
//#define RENDER_COMPOSITE_BLOOM_BLUR_H

varying vec2 texcoord;

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex4;
    uniform sampler2D colortex7;

    uniform float viewWidth;
    uniform float viewHeight;

    #include "/lib/bloom.glsl"

    const vec2 direction = vec2(1.0, 0.0);


    void main() {
        vec2 tileMin, tileMax;
        int tileCount = GetBloomTileCount();
        int tile = GetBloomTileInnerIndex(tileCount, tileMin, tileMax);

        vec3 final = vec3(0.0);
        if (tile >= 0) final = BloomBlur13(texcoord, tileMin, tileMax, direction);

    /* DRAWBUFFERS:7 */
        gl_FragData[0] = vec4(final, 1.0);
    }
#endif
