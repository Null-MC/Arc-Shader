#extension GL_ARB_texture_query_levels : enable

#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    out vec4 glcolor;
    flat out float sunLightLevel;
    flat out float moonLightLevel;
    flat out vec3 sunLightLum;
    flat out vec3 moonLightLum;
    flat out float exposure;
    
    uniform float screenBrightness;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
        
        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform int moonPhase;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
        uniform int heldBlockLightValue;
    #endif

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        glcolor = gl_Color;

        exposure = GetExposure();

        vec2 skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);
        sunLightLevel = GetSunLightLevel(skyLightLevels.x);
        moonLightLevel = GetMoonLightLevel(skyLightLevels.y);
        sunLightLum = GetSunLightColor(skyLightTemp.x, skyLightLevels.x) * sunLumen;
        moonLightLum = GetMoonLightColor(skyLightTemp.y, skyLightLevels.y) * moonLumen;
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    in vec4 glcolor;
    flat in float sunLightLevel;
    flat in float moonLightLevel;
    flat in vec3 sunLightLum;
    flat in vec3 moonLightLum;
    flat in float exposure;

    uniform sampler2D gtexture;
    //uniform sampler2D BUFFER_LUMINANCE;

    //uniform float viewWidth;
    //uniform float viewHeight;
    uniform int renderStage;

    /* RENDERTARGETS: 4 */
    out vec4 outColor0;

    //#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
    //    out vec4 outLuminance;
    //#endif


    void main() {
        outColor0 = textureLod(gtexture, texcoord, 0);
        outColor0.rgb = RGBToLinear(outColor0.rgb * glcolor.rgb);

        if (renderStage == MC_RENDER_STAGE_SUN) {
            outColor0.rgb *= sunLightLum;
            outColor0.a *= sunLightLevel;
        }
        else if (renderStage == MC_RENDER_STAGE_MOON) {
            outColor0.rgb *= moonLightLum;
            outColor0.a *= moonLightLevel;
        }

        // #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        //     //ivec2 itex = ivec2(gl_FragCoord.xy);
        //     //float skyLum = texelFetch(BUFFER_LUMINANCE, itex, 0).r;
        //     //skyLum = exp2(skyLum) - EPSILON;

        //     float lum = log2(sunLightLevel * sunLumen + EPSILON);
        //     //float finalLum = mix(skyLum, lum, outColor.a);
        //     outLuminance = vec4(lum, 0.0, 0.0, 1.0);
        // #endif

        outColor0.rgb = clamp(outColor0.rgb * exposure, vec3(0.0), vec3(65000));
    }
#endif
