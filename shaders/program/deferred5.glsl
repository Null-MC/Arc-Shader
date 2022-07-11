#extension GL_ARB_texture_query_levels : enable

#define RENDER_DEFERRED
//#define RENDER_DEFERRED_ATMOSPHERE

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    flat out float exposure;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform int heldBlockLightValue;
    #endif

    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelView;


    #include "/lib/camera/exposure.glsl"


    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        gl_Position = ftransform();

        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
                vec2 skyLightIntensity = GetSkyLightIntensity();
                vec2 eyeBrightness = eyeBrightnessSmooth / 240.0;
                float averageLuminance = GetAverageLuminance_EyeBrightness(eyeBrightness, skyLightIntensity);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                int luminanceLod = textureQueryLevels(BUFFER_HDR_PREVIOUS)-1;
                float averageLuminance = GetAverageLuminance_Mipmap(luminanceLod);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_HISTOGRAM
                float averageLuminance = GetAverageLuminance_Histogram();
            #else
                const float averageLuminance = 0.0;
            #endif

            float EV100 = GetEV100(averageLuminance);
        #else
            const float EV100 = 0.0;
        #endif

        exposure = GetExposure(EV100 - CAMERA_EXPOSURE);
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    flat in float exposure;

    uniform sampler2D BUFFER_HDR;
    uniform sampler2D depthtex0;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_LUMINANCE;
    #endif

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform float eyeAltitude;
    uniform vec3 sunPosition;
    uniform float viewWidth;
    uniform float viewHeight;


    #include "/lib/world/atmosphere.glsl"

    /* DRAWBUFFERS:46 */
    out vec3 outColor;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        out float outLuminance;
    #endif


    void main() {
        ivec2 itex = ivec2(texcoord * vec2(viewWidth, viewHeight));
        float depth = texelFetch(depthtex0, itex, 0).r;

        outColor = texelFetch(BUFFER_HDR, itex, 0).rgb;

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            outLuminance = texelFetch(BUFFER_LUMINANCE, itex, 0).r;
        #endif

        if (depth >= 1.0 - EPSILON) {
            vec3 clipPos = vec3(texcoord, depth) * 2.0 - 1.0;
            vec4 viewPos = gbufferProjectionInverse * vec4(clipPos, 1.0);
            viewPos.xyz /= viewPos.w;

            vec3 localSunPos = mat3(gbufferModelViewInverse) * sunPosition;
            vec3 localSunDir = normalize(localSunPos);

            vec3 localViewPos = mat3(gbufferModelViewInverse) * viewPos.xyz;

            ScatteringParams setting;
            setting.sunRadius = 3000.0;
            setting.sunRadiance = 441.0 * WM2ToLumen;
            setting.mieG = 0.96;
            setting.mieHeight = 1200.0;
            setting.rayleighHeight = 8000.0;
            setting.earthRadius = 6360000.0;
            setting.earthAtmTopRadius = 6420000.0;
            setting.earthCenter = vec3(0.0, -6360000.0, 0.0);
            setting.waveLambdaMie = vec3(2e-7);

            vec3 localViewDir = normalize(localViewPos);
            
            // wavelength with 680nm, 550nm, 450nm
            setting.waveLambdaRayleigh = ComputeWaveLambdaRayleigh(vec3(680e-9, 550e-9, 450e-9));
            
            // see https://www.shadertoy.com/view/MllBR2
            setting.waveLambdaOzone = vec3(1.36820899679147, 3.31405330400124, 0.13601728252538) * 0.6e-6 * 2.504;

            vec3 eye = vec3(0.0, 200.0 * eyeAltitude, 0.0);

            vec4 sky = ComputeSkyInscattering(setting, eye, localViewDir, localSunDir);

            #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                outLuminance = log(luminance(sky.rgb) + EPSILON);
            #endif

            outColor += sky.rgb * exposure;
        }
    }
#endif
