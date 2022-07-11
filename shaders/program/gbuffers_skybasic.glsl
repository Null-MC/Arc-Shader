#extension GL_ARB_texture_query_levels : enable

#define RENDER_GBUFFER
#define RENDER_SKYBASIC

varying vec3 starData;

#ifdef RENDER_VERTEX
    flat out float exposure;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    //uniform ivec2 eyeBrightnessSmooth;

    #include "/lib/lighting/blackbody.glsl"

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightnessSmooth;
        uniform int heldBlockLightValue;
        uniform float rainStrength;

        uniform vec3 upPosition;
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform int moonPhase;

        #include "/lib/world/sky.glsl"
    #endif

    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();

        float starFactor = pow(gl_Color.r, GAMMA) * float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);

        float starTemp = mix(5300, 6000, starFactor);
        starData = blackbody(starTemp) * starFactor * StarLumen;

        exposure = GetExposure();
    }
#endif

#ifdef RENDER_FRAG
    flat in float exposure;

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferProjectionInverse;
    uniform float viewWidth;
    uniform float viewHeight;
    
    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 fogColor;
    uniform vec3 skyColor;
    uniform int moonPhase;

    #include "/lib/world/sky.glsl"

    /* DRAWBUFFERS:46 */
    out vec3 outColor;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        out float outLuminance;
    #endif


    void main() {
        vec3 color = starData;

        #ifndef ATMOSPHERE_ENABLED
            vec3 clipPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0) * 2.0 - 1.0;
            vec4 viewPos = gbufferProjectionInverse * vec4(clipPos, 1.0);
            viewPos.xyz /= viewPos.w;

            vec3 viewDir = normalize(viewPos.xyz);
            color += GetVanillaSkyColor(viewDir);
        #endif

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            outLuminance = log(luminance(color) + EPSILON);
        #endif

        outColor = clamp(color * exposure, vec3(0.0), vec3(65000));
    }
#endif
