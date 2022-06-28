#define RENDER_COMPOSITE

varying vec2 texcoord;

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex0;

    #if defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER != 0
        uniform sampler2D shadowcolor0;
        uniform sampler2D shadowtex0;
        uniform sampler2D shadowtex1;
    #endif


    void main() {
        #if defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 1
            vec3 color = texture2D(shadowcolor0, texcoord).rgb;
        #elif defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 2
            vec3 color = texture2D(shadowtex0, texcoord).rrr;
        #elif defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 3
            vec3 color = texture2D(shadowtex1, texcoord).rrr;
        #else
            vec3 color = texture2D(colortex0, texcoord).rgb;
        #endif

    /* DRAWBUFFERS:4 */
        gl_FragData[0] = vec4(color, 1.0); //gaux1
    }
#endif
