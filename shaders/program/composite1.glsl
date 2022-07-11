#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_PREV_FRAME

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

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_LUMINANCE;
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif
    
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float frameTimeCounter;
    uniform float frameTime;


    void main() {
        vec3 color = textureLod(BUFFER_HDR, texcoord, 0).rgb;
        float lum = 0.0;

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            lum = textureLod(BUFFER_LUMINANCE, texcoord, 0).r;
            lum = max(exp(lum) - EPSILON, 0.0);

            ivec2 iuv = ivec2(texcoord * 0.5 * vec2(viewWidth, viewHeight));
            float lumPrev = texelFetch(BUFFER_HDR_PREVIOUS, iuv, 0).a;
            lumPrev = max(exp(lumPrev) - EPSILON, 0.0);

            const float timeDeltaF = 1.0 / 3600.0;
            float timeDelta = (frameTimeCounter - frameTime) * timeDeltaF;
            timeDelta += step(frameTime, frameTimeCounter);

            float speed = 0.0;
            speed += step(lum + EPSILON, lumPrev) * EXPOSURE_SPEED_DOWN;
            speed += step(lumPrev + EPSILON, lum) * EXPOSURE_SPEED_UP;

            lum = lumPrev + (lum - lumPrev) * (1.0 - exp(-timeDelta * TAU * speed));
            //lum = clamp(lum, CAMERA_LUM_MIN, CAMERA_LUM_MAX);
            lum = log(lum + EPSILON);
        #endif

    /* DRAWBUFFERS:5 */
        gl_FragData[0] = vec4(color, lum);
    }
#endif
