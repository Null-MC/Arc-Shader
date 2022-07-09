#define RENDER_DEFERRED
//#define RENDER_DEFERRED_ATMOSPHERE

#ifdef RENDER_VERTEX
    out vec2 texcoord;

    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelView;


    void main() {
        //texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        texcoord = gl_MultiTexCoord0.xy;

        gl_Position = gbufferProjection * gbufferModelView * gl_Vertex;
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;

    uniform sampler2D BUFFER_HDR;
    uniform sampler2D depthtex0;

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform float eyeAltitude;
    uniform vec3 sunPosition;
    uniform float viewWidth;
    uniform float viewHeight;


    #include "/lib/world/atmosphere.glsl"

    /* DRAWBUFFERS:4 */
    out vec3 outColor;


    void main() {
        ivec2 itex = ivec2(texcoord * vec2(viewWidth, viewHeight));
        float depth = texelFetch(depthtex0, itex, 0).r;

        if (depth >= 1.0 - EPSILON) {
            vec3 clipPos = vec3(texcoord, depth) * 2.0 - 1.0;
            vec4 viewPos = gbufferProjectionInverse * vec4(clipPos, 1.0);
            viewPos.xyz /= viewPos.w;

            vec3 localSunPos = mat3(gbufferModelViewInverse) * sunPosition;
            vec3 localSunDir = normalize(localSunPos);

            vec3 localViewPos = mat3(gbufferModelViewInverse) * viewPos.xyz;

            ScatteringParams setting;
            setting.sunRadius = 3000.0;
            setting.sunRadiance = 120.0;
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

            outColor = sky.rgb;
        }
        else {
            outColor = texelFetch(BUFFER_HDR, itex, 0).rgb;
        }
    }
#endif
