#define RENDER_DEFERRED
//#define RENDER_DEFERRED_ATMOSPHERE

varying vec2 texcoord;

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    //uniform sampler2D colortex3;
    uniform sampler2D colortex4;
    uniform sampler2D depthtex0;

    //uniform mat4 gbufferModelView;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform float eyeAltitude;
    uniform vec3 sunPosition;
    uniform float viewWidth;
    uniform float viewHeight;
    // uniform vec3 fogColor;
    // uniform vec3 skyColor;
    // uniform float fogStart;
    // uniform float fogEnd;


    #include "/lib/world/atmosphere.glsl"
    //#include "/lib/world/fog.glsl"


    void main() {
        ivec2 itex = ivec2(texcoord * vec2(viewWidth, viewHeight));
        float depth = texelFetch(depthtex0, itex, 0).r;

        vec3 color;
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

            color = sky.rgb;
        }
        else {
            color = texelFetch(colortex4, itex, 0).rgb;
        }

    /* DRAWBUFFERS:4 */
        gl_FragData[0] = vec4(color, 1.0);
    }
#endif
