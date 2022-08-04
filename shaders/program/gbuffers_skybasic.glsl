#extension GL_ARB_texture_query_levels : enable

#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#ifdef RENDER_VERTEX
    out vec3 starData;
    flat out float sunLightLevel;
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out float exposure;

    uniform float screenBrightness;
    uniform float blindness;
    
    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
        
        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    //uniform ivec2 eyeBrightnessSmooth;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
        uniform int heldBlockLightValue;
    #endif

    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();

        float starFactor = pow(gl_Color.r, GAMMA) * float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);

        float starTemp = mix(5300, 6000, starFactor);
        starData = blackbody(starTemp) * starFactor * StarLumen;

        vec2 skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
        sunColor = GetSunLightLuxColor(skyLightTemps.x, skyLightLevels.x);
        moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);
        sunLightLevel = GetSunLightLevel(skyLightLevels.x);

        exposure = GetExposure();
    }
#endif

#ifdef RENDER_FRAG
    in vec3 starData;
    flat in float sunLightLevel;
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in float exposure;

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferProjectionInverse;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float far;
    
    uniform int isEyeInWater;
    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 fogColor;
    uniform vec3 skyColor;
    uniform int moonPhase;

    #ifdef IS_OPTIFINE
        uniform float eyeHumidity;
    #endif

    #include "/lib/world/scattering.glsl"

    #if ATMOSPHERE_TYPE == ATMOSPHERE_TYPE_FANCY
        uniform mat4 gbufferModelViewInverse;
        uniform float eyeAltitude;
        uniform float near;

        #include "/lib/world/atmosphere.glsl"
    #else
        uniform float near;
        //uniform float far;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"

    /* RENDERTARGETS: 4,6 */
    out vec3 outColor0;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        out float outColor1;
    #endif


    void main() {
        vec3 color = starData;

        vec3 clipPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0) * 2.0 - 1.0;
        vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

        #if ATMOSPHERE_TYPE == ATMOSPHERE_TYPE_FANCY
            vec3 localSunPos = mat3(gbufferModelViewInverse) * sunPosition;
            vec3 localSunDir = normalize(localSunPos);

            vec3 localViewPos = mat3(gbufferModelViewInverse) * viewPos;

            ScatteringParams setting;
            setting.sunRadius = 3000.0;
            setting.sunRadiance = sunLightLevel * sunLumen;
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

            color += sky.rgb;
        #else
            vec3 viewDir = normalize(viewPos);
            color += GetVanillaSkyLuminance(viewDir);
            color += GetVanillaSkyScattering(viewDir, sunColor, moonColor);
        #endif

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            float lum = luminance(color);

            // #if ATMOSPHERE_TYPE == ATMOSPHERE_TYPE_FAST
            //     vec3 sunDir = normalize(sunPosition);
            //     float VoSun = max(dot(viewDir, sunDir), 0.0);
            //     float sunDot = saturate((VoSun - 0.9997) * rcp(0.0003));
            //     lum += pow(sunDot, 0.5) * sunLumen;

            //     vec3 moonDir = normalize(moonPosition);
            //     float VoMoon = max(dot(viewDir, moonDir), 0.0);
            //     float moonDot = saturate((VoMoon - 0.9994) * rcp(0.0006));
            //     lum += pow(moonDot, 0.5) * moonLumen;
            // #endif

            outColor1 = log2(lum + EPSILON);
        #endif

        outColor0 = clamp(color * exposure, vec3(0.0), vec3(65000));
    }
#endif
