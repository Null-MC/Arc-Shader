#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_PREV_LUMINANCE

#ifdef RENDER_VERTEX
    out vec2 texcoord;


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;


    uniform sampler2D BUFFER_HDR;
    uniform sampler2D BUFFER_LUMINANCE;

    uniform float frameTimeCounter;
    uniform float frameTime;
    uniform float viewWidth;
    uniform float viewHeight;
    

    void main() {
        vec3 color = textureLod(BUFFER_HDR, texcoord, 0).rgb;

        float lum = 0.0;
        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            ivec2 iuv = ivec2(texcoord * 0.5 * vec2(viewWidth, viewHeight));
            //float lumPrev = texelFetch(BUFFER_LUMINANCE, iuv, 0).r;
            vec4 samples = textureGather(BUFFER_LUMINANCE, texcoord);
            float lumPrev = 0.25 * (samples[0] + samples[1] + samples[2] + samples[3]);

            lum = log(luminance(color));

            float timeDelta = (frameTimeCounter - frameTime) / 3600;
            timeDelta += step(timeDelta, -EPSILON);

            lum = lumPrev + (lum - lumPrev) * (1.0 - exp(-timeDelta * TAU * EXPOSURE_SPEED));
        #endif

    /* DRAWBUFFERS:56 */
        gl_FragData[0] = vec4(color, 1.0);
        gl_FragData[1] = vec4(lum, 0.0, 0.0, 1.0);
    }
#endif
