#extension GL_ARB_shading_language_packing : enable
#extension GL_ARB_texture_query_levels : enable

#define RENDER_GBUFFER
#define RENDER_WEATHER

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#ifdef RENDER_VERTEX
    out vec2 lmcoord;
    out vec2 texcoord;
    out vec4 glcolor;
    out float geoNoL;
    out vec3 viewPos;
    out vec3 viewNormal;
    flat out float exposure;

    #ifdef HANDLIGHT_ENABLED
        flat out vec3 blockLightColor;
    #endif

    #if defined HANDLIGHT_ENABLED || CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform int heldBlockLightValue;
        uniform int heldBlockLightValue2;
    #endif

    #ifdef SKY_ENABLED
        flat out vec3 sunColor;
        flat out vec3 moonColor;
        flat out vec3 skyLightColor;
        
        uniform float rainStrength;
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;
        uniform int moonPhase;

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform mat4 gbufferModelView;
            uniform mat4 gbufferModelViewInverse;
            uniform vec3 shadowLightPosition;
            uniform mat4 shadowModelView;
            uniform mat4 shadowProjection;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                attribute vec3 at_midBlock;

                flat out float cascadeSizes[4];
                flat out vec3 matShadowProjections_scale[4];
                flat out vec3 matShadowProjections_translation[4];

                #ifdef IS_OPTIFINE
                    uniform mat4 gbufferPreviousProjection;
                    uniform mat4 gbufferPreviousModelView;
                #endif

                uniform mat4 gbufferProjection;
                uniform float near;
                uniform float far;
            #endif
        #endif
    #endif

    uniform float screenBrightness;
    uniform vec3 cameraPosition;
    uniform float blindness;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
        
        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
        //uniform int heldBlockLightValue;
    #endif
  
    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif
  
    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;

        vec3 localPos = gl_Vertex.xyz;
        BasicVertex(localPos);
        
        #ifdef HANDLIGHT_ENABLED
            blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;
        #endif

        vec2 skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
        sunColor = GetSunLightColor(skyLightTemps.x, skyLightLevels.x) * sunLumen;
        moonColor = GetMoonLightColor(skyLightTemps.y, skyLightLevels.y) * moonLumen;
        skyLightColor = GetSkyLightLuxColor(skyLightLevels);

        exposure = GetExposure();
    }
#endif

#ifdef RENDER_FRAG
    in vec2 lmcoord;
    in vec2 texcoord;
    in vec4 glcolor;
    in vec3 viewPos;
    in vec3 viewNormal;
    in float geoNoL;
    flat in float exposure;

    #ifdef HANDLIGHT_ENABLED
        flat in vec3 blockLightColor;

        uniform int heldBlockLightValue;
        uniform int heldBlockLightValue2;
    #endif

    #ifdef SKY_ENABLED
        uniform float rainStrength;
        uniform vec3 skyColor;
        uniform float wetness;
        uniform int moonPhase;

        #ifdef SHADOW_ENABLED
            flat in vec3 sunColor;
            flat in vec3 moonColor;
            flat in vec3 skyLightColor;

            uniform vec3 shadowLightPosition;
            uniform vec3 sunPosition;
            uniform vec3 moonPosition;
            uniform vec3 upPosition;

            #if SHADOW_TYPE != SHADOW_TYPE_NONE
                uniform sampler2D shadowtex0;

                #ifdef SHADOW_COLOR
                    uniform sampler2D shadowcolor0;
                #endif

                #ifdef SSS_ENABLED
                    uniform usampler2D shadowcolor1;
                #endif

                #ifdef SHADOW_ENABLE_HWCOMP
                    #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                        uniform sampler2DShadow shadowtex1HW;
                        uniform sampler2D shadowtex1;
                    #else
                        uniform sampler2DShadow shadowtex1;
                    #endif
                #else
                    uniform sampler2D shadowtex1;
                #endif

                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    flat in float cascadeSizes[4];
                    flat in vec3 matShadowProjections_scale[4];
                    flat in vec3 matShadowProjections_translation[4];
                #else
                    uniform mat4 shadowProjection;
                #endif
                
                #if defined VL_ENABLED && defined VL_PARTICLES
                    uniform mat4 shadowModelView;
                    uniform mat4 gbufferModelViewInverse;
                    uniform float viewWidth;
                    uniform float viewHeight;
                #endif
            #endif
        #endif
    #endif

    uniform sampler2D gtexture;
    uniform sampler2D lightmap;

    uniform ivec2 eyeBrightnessSmooth;
    uniform float near;
    uniform float far;

    uniform vec3 fogColor;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogShape;
    uniform int fogMode;

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #ifdef IS_OPTIFINE
        uniform float eyeHumidity;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/lighting/light_data.glsl"
    #include "/lib/world/scattering.glsl"

    #ifdef HANDLIGHT_ENABLED
        #include "/lib/lighting/basic_handlight.glsl"
    #endif

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if SHADOW_PCF_SAMPLES == 12
            #include "/lib/sampling/poisson_12.glsl"
        #elif SHADOW_PCF_SAMPLES == 24
            #include "/lib/sampling/poisson_24.glsl"
        #elif SHADOW_PCF_SAMPLES == 36
            #include "/lib/sampling/poisson_36.glsl"
        #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #else
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif

        #if defined VL_ENABLED && defined VL_PARTICLES
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif

    #include "/lib/world/sky.glsl"
    #include "/lib/world/fog.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/basic_forward.glsl"

    /* RENDERTARGETS: 4,6 */
    out vec4 outColor0;
    out vec4 outColor1;


    void main() {
        vec4 color = BasicLighting();
        color.a *= WEATHER_OPACITY * 0.01;

        vec4 outLuminance = vec4(0.0);
        outLuminance.r = log2(luminance(color.rgb) * color.a + EPSILON);
        outLuminance.a = color.a;
        outColor1 = outLuminance;

        color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
        outColor0 = color;
    }
#endif
