#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_PREV_FRAME

#ifdef RENDER_VERTEX
    out vec2 texcoord;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        flat out float eyeLum;

        uniform int heldBlockLightValue;
        uniform ivec2 eyeBrightness;

        uniform float rainStrength;
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;
        uniform int moonPhase;

        uniform vec3 skyColor;
        uniform vec3 fogColor;

        #include "/lib/lighting/blackbody.glsl"
        #include "/lib/world/sky.glsl"

        float GetEyeBrightnessLuminance() {
            vec2 eyeBrightnessLinear = saturate2(eyeBrightness / 240.0);

            vec2 skyLightLevels = GetSkyLightLevels();
            float sunLightLux = GetSunLightLevel(skyLightLevels.x) * SunLux;
            float moonLightLux = GetMoonLightLevel(skyLightLevels.y) * MoonLux;
            float skyLightBrightness = pow3(eyeBrightnessLinear.y) * (sunLightLux + moonLightLux);

            float blockLightBrightness = eyeBrightnessLinear.x;

            #ifdef HANDLIGHT_ENABLED
                blockLightBrightness = max(blockLightBrightness, heldBlockLightValue * 0.0625);
            #endif

            blockLightBrightness = pow3(blockLightBrightness) * BlockLightLux;

            return 10.0 + 0.1 * max(blockLightBrightness, skyLightBrightness);
        }
    #endif


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
            eyeLum = GetEyeBrightnessLuminance();
        #endif
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        flat in float eyeLum;
    #endif

    uniform sampler2D BUFFER_HDR;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_LUMINANCE;
    #endif

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        uniform sampler2D depthtex0;
    #endif
    
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float frameTime;

    /* RENDERTARGETS: 5,12 */
    out vec4 outColor0;
    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        out float outColor1;
    #endif


    void main() {
        vec3 color = textureLod(BUFFER_HDR, texcoord, 0).rgb;
        float lum = 0.0;

        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
                lum = eyeLum;
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                lum = textureLod(BUFFER_LUMINANCE, texcoord, 0).r;
                lum = max(exp2(lum) - EPSILON, 0.0);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_HISTOGRAM
                lum = 0.0;
            #endif

            ivec2 iuv = ivec2(texcoord * 0.5 * vec2(viewWidth, viewHeight));
            float lumPrev = texelFetch(BUFFER_HDR_PREVIOUS, iuv, 0).a;
            lumPrev = max(exp2(lumPrev) - EPSILON, 0.0);

            lum = clamp(lum, 0.0, 1.0e6);
            lumPrev = clamp(lumPrev, 0.0, 1.0e6);

            float dir = step(lumPrev, lum);
            float speed = (1.0 - dir) * EXPOSURE_SPEED_DOWN + dir * EXPOSURE_SPEED_UP;
            float timeF = exp(-frameTime * TAU * speed);

            lum = lumPrev + (lum - lumPrev) * clamp(1.0 - timeF, EPSILON, 1.0);
            //lum = clamp(lum, CAMERA_LUM_MIN, CAMERA_LUM_MAX);
            lum = log2(lum + EPSILON);
        #endif

        outColor0 = vec4(color, lum);

        #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
            float depth = 1.0;

            depth = textureLod(depthtex0, texcoord, 1).r;

            outColor1 = depth;
        #endif
    }
#endif
