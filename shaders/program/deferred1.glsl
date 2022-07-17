#define RENDER_DEFERRED
//#define RENDER_WATER_WAVES

#ifdef RENDER_VERTEX
    out vec2 texcoord;

    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;

    uniform vec3 cameraPosition;
    uniform float frameTimeCounter;
    uniform float frameTime;

    #include "/lib/world/gerstner_waves.glsl"

    /* RENDERTARGETS: 11 */
    out vec3 outColor0;


    void main() {
        // TODO

        outColor0 = vec3(0.0);
    }
#endif
