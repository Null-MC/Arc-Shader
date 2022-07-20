#define RENDER_DEFERRED
//#define RENDER_DEFERRED_REFRACT

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D BUFFER_HDR;

    /* RENDERTARGETS: 7 */
    out vec4 outColor0;


    void main() {
        vec3 color = texelFetch(BUFFER_HDR, ivec2(gl_FragCoord.xy * 0.5), 1).rgb;
        outColor0 = vec4(color, 1.0);
    }
#endif
