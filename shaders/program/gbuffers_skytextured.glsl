#extension GL_ARB_texture_query_levels : enable

#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    out vec4 glcolor;
    flat out float sunLightLevel;
    flat out float moonLightLevel;
    flat out vec3 sunLightLumColor;
    flat out vec3 moonLightLumColor;
    flat out float exposure;
    
    uniform float screenBrightness;
    uniform float blindness;

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

    #ifdef IS_OPTIFINE
        uniform mat4 gbufferModelView;
        uniform int worldTime;
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
        sunLightLumColor = GetSunLightColor(skyLightTemp.x, skyLightLevels.x) * sunLumen;
        moonLightLumColor = GetMoonLightColor(skyLightTemp.y, skyLightLevels.y) * moonLumen;
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    in vec4 glcolor;
    flat in float sunLightLevel;
    flat in float moonLightLevel;
    flat in vec3 sunLightLumColor;
    flat in vec3 moonLightLumColor;
    flat in float exposure;

    uniform sampler2D gtexture;
    //uniform sampler2D BUFFER_LUMINANCE;

    //uniform float viewWidth;
    //uniform float viewHeight;
    uniform int renderStage;

    /* RENDERTARGETS: 4,6 */
    //out vec4 outColor0;

    //#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        //out vec4 outColor1;
    //#endif


    void main() {
        vec3 color = textureLod(gtexture, texcoord, 0).rgb;
        color = RGBToLinear(color * glcolor.rgb);
        //if (color.a < 0.5) discard;

        float lum = saturate(luminance(color));
        float lumF = 0.0;

        if (renderStage == MC_RENDER_STAGE_SUN) {
            color *= sunLightLumColor * sunLightLevel;
            lum *= sunLightLevel;

            lumF += sunLumen;
        }
        else if (renderStage == MC_RENDER_STAGE_MOON) {
            color *= moonLightLumColor * moonLightLevel;
            lum *= moonLightLevel;

            lumF += moonLumen;
        }

        color = clamp(color * exposure, vec3(0.0), vec3(65000));
        gl_FragData[0] = vec4(color, lum);

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            float lumFinal = log2(lum * lumF + EPSILON);
            gl_FragData[1] = vec4(lumFinal, 0.0, 0.0, lum);
        #endif
    }
#endif
