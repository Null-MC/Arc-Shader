#extension GL_ARB_texture_query_levels : enable

#define RENDER_GBUFFER
#define RENDER_CLOUDS

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    out vec4 glcolor;
    flat out float exposure;
    
    uniform float screenBrightness;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
        
        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
        uniform int heldBlockLightValue;

        uniform float rainStrength;
        uniform vec3 upPosition;
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform int moonPhase;

        #include "/lib/lighting/blackbody.glsl"
        #include "/lib/world/sky.glsl"
    #endif

    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        glcolor = gl_Color;

        exposure = GetExposure();
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    in vec4 glcolor;
    flat in float exposure;

    uniform sampler2D gtexture;

    uniform float rainStrength;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 fogColor;
    uniform vec3 skyColor;
    uniform int moonPhase;

    /* DRAWBUFFERS:46 */
    out vec4 outColor;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        out float outLuminance;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"


    void main() {
        vec4 colorMap = texture(gtexture, texcoord) * glcolor;
        colorMap.rgb = RGBToLinear(colorMap.rgb);

        vec2 skyLightLevels = GetSkyLightLevels();
        float sunLightLux = GetSunLightLevel(skyLightLevels.x) * DaySkyLumen;
        float moonLightLux = GetMoonLightLevel(skyLightLevels.y) * NightSkyLumen;
        colorMap.rgb *= sunLightLux + moonLightLux;

        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            outLuminance = log2(luminance(colorMap.rgb) + EPSILON);
        #endif

        colorMap.rgb = clamp(colorMap.rgb * exposure, vec3(0.0), vec3(65000));
        outColor = colorMap;
    }
#endif
