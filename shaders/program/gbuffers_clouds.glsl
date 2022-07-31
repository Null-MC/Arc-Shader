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

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
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

    #ifdef IS_OPTIFINE
        uniform float eyeHumidity;

        #if MC_VERSION >= 11700
            uniform float alphaTestRef;
        #endif
    #endif

    /* RENDERTARGETS: 4,6 */
    out vec4 outColor0;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        out float outColor1;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/scattering.glsl"
    #include "/lib/world/sky.glsl"


    void main() {
        vec4 colorMap = texture(gtexture, texcoord);
        colorMap.rgb = RGBToLinear(colorMap.rgb * glcolor.rgb);

        if (colorMap.a < alphaTestRef) discard;

        vec2 skyLightLevels = GetSkyLightLevels();
        float darkness = 1.0 - 0.65 * rainStrength;
        colorMap.rgb *= GetSkyLightLuminance(skyLightLevels) * darkness;

        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            outColor1 = log2(luminance(colorMap.rgb) + EPSILON);
        #endif

        colorMap.rgb = clamp(colorMap.rgb * exposure, vec3(0.0), vec3(65000));
        outColor0 = colorMap;
    }
#endif
