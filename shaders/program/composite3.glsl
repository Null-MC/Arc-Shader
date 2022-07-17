#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE
#define RENDER_COMPOSITE_BLOOM_BLUR
//#define RENDER_COMPOSITE_BLOOM_BLUR_V

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    flat out int tileCount;

    uniform sampler2D BUFFER_HDR;

    #include "/lib/camera/bloom.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        tileCount = GetBloomTileCount();
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    flat in int tileCount;

    uniform sampler2D BUFFER_BLOOM;

    uniform float viewWidth;
    uniform float viewHeight;

    #include "/lib/camera/bloom.glsl"

    const vec2 direction = vec2(0.0, 1.0);

    /* RENDERTARGETS: 7 */
    out vec3 outColor0;


    void main() {
        vec2 tileMin, tileMax;
        int tile = GetBloomTileInnerIndex(tileCount, tileMin, tileMax);

        vec3 final = vec3(0.0);
        if (tile >= 0) final = BloomBlur13(texcoord, tileMin, tileMax, direction);

        outColor0 = final;
    }
#endif
