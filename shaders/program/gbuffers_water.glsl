#extension GL_ARB_texture_query_levels : enable
#extension GL_ARB_gpu_shader5 : enable

#define RENDER_GBUFFER
#define RENDER_WATER

#ifdef RENDER_VERTEX
    out vec2 lmcoord;
    out vec2 texcoord;
    out vec4 glcolor;
    out vec3 viewPos;
    out vec3 viewNormal;
    out float geoNoL;
    out mat3 matTBN;
    out vec3 tanViewPos;
    flat out float exposure;
    flat out int materialId;

    #ifdef PARALLAX_ENABLED
        out mat2 atlasBounds;
        out vec2 localCoord;
    #endif

    #ifdef SHADOW_ENABLED
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;

        out vec3 tanLightPos;
        flat out vec3 skyLightColor;

        #if SHADOW_TYPE == 3
            out vec3 shadowPos[4];
            out vec3 shadowParallaxPos[4];
            out vec2 shadowProjectionSizes[4];
            out float cascadeSizes[4];
            flat out int shadowCascade;
        #elif SHADOW_TYPE != 0
            out vec4 shadowPos;
            out vec4 shadowParallaxPos;
        #endif
    #endif

    #ifdef AF_ENABLED
        out vec4 spriteBounds;
    #endif

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
        
        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
        uniform int heldBlockLightValue;
    #endif

    in vec4 mc_Entity;
    in vec3 vaPosition;
    in vec4 at_tangent;
    in vec3 at_midBlock;

    #if defined PARALLAX_ENABLED || defined AF_ENABLED
        in vec4 mc_midTexCoord;
    #endif

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;
    uniform float screenBrightness;
    uniform vec3 cameraPosition;

    uniform float rainStrength;
    uniform int moonPhase;

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform vec3 chunkOffset;
    #endif

    #ifdef SHADOW_ENABLED
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform vec3 shadowLightPosition;
        uniform float far;

        #if SHADOW_TYPE == 3
            #ifdef IS_OPTIFINE
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

            uniform mat4 gbufferProjection;
            uniform float near;

            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #elif SHADOW_TYPE != 0
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/pbr.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;

        mat3 matViewTBN;
        BasicVertex(matViewTBN);
        PbrVertex(matViewTBN);

        vec2 skyLightLevels = GetSkyLightLevels();
        skyLightColor = GetSkyLightLuminance(skyLightLevels);

        if (mc_Entity.x == 100.0) materialId = 1;
        else materialId = 0;

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
    in mat3 matTBN;
    in vec3 tanViewPos;
    flat in float exposure;
    flat in int materialId;

    #ifdef PARALLAX_ENABLED
        in mat2 atlasBounds;
        in vec2 localCoord;
    #endif

    #ifdef SHADOW_ENABLED
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;

        in vec3 tanLightPos;
        flat in vec3 skyLightColor;

        #if SHADOW_TYPE == 3
            in vec3 shadowPos[4];
            in vec3 shadowParallaxPos[4];
            in vec2 shadowProjectionSizes[4];
            in float cascadeSizes[4];
            flat in int shadowCascade;
        #elif SHADOW_TYPE != 0
            in vec4 shadowPos;
            in vec4 shadowParallaxPos;
        #endif
    #endif

    #ifdef AF_ENABLED
        in vec4 spriteBounds;
    #endif

    uniform sampler2D gtexture;
    uniform sampler2D normals;
    uniform sampler2D specular;
    uniform sampler2D lightmap;
    uniform sampler2D gcolor;
    uniform sampler2D colortex10; // IBL DFG_LUT

    uniform ivec2 eyeBrightnessSmooth;
    uniform int heldBlockLightValue;
    uniform float rainStrength;
    uniform int moonPhase;
    uniform float near;

    uniform vec3 skyColor;
    uniform vec3 fogColor;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogMode;
    uniform int fogShape;

    #ifdef AF_ENABLED
        uniform float viewHeight;
    #endif

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;

        #if SHADOW_TYPE != 0
            uniform usampler2D shadowcolor0;
            uniform sampler2D shadowtex0;
        
            uniform float far;

            #if SHADOW_TYPE == 3
                uniform isampler2D shadowcolor1;
            #endif

            #if !defined IS_OPTIFINE && defined SHADOW_ENABLE_HWCOMP
                uniform sampler2DShadow shadowtex1HW;
                uniform sampler2D shadowtex1;
            #else
                uniform sampler2DShadow shadowtex1;
            #endif

            #if SHADOW_PCF_SAMPLES == 12
                #include "/lib/sampling/poisson_12.glsl"
            #elif SHADOW_PCF_SAMPLES == 24
                #include "/lib/sampling/poisson_24.glsl"
            #elif SHADOW_PCF_SAMPLES == 36
                #include "/lib/sampling/poisson_36.glsl"
            #endif

            #if SHADOW_TYPE == 3
                #include "/lib/shadows/csm.glsl"
                #include "/lib/shadows/csm_render.glsl"
            #else
                uniform mat4 shadowProjection;

                #include "/lib/shadows/basic.glsl"
                #include "/lib/shadows/basic_render.glsl"
            #endif
        #endif
    #endif

    #ifdef PARALLAX_ENABLED
        uniform ivec2 atlasSize;

        #ifdef PARALLAX_SMOOTH
            #include "/lib/sampling/linear.glsl"
        #endif

        #include "/lib/parallax.glsl"
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/fog.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/material.glsl"
    #include "/lib/lighting/material_reader.glsl"
    #include "/lib/lighting/hcm.glsl"
    #include "/lib/lighting/pbr.glsl"
    #include "/lib/lighting/pbr_forward.glsl"

    /* DRAWBUFFERS:46 */
    out vec4 outColor;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        out vec4 outLuminance;
    #endif


    void main() {
        outColor = PbrLighting();

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            outLuminance.r = log2(luminance(outColor.rgb) + EPSILON);
            outLuminance.a = outColor.a;
        #endif

        outColor.rgb = clamp(outColor.rgb * exposure, vec3(0.0), vec3(65000));
    }
#endif
