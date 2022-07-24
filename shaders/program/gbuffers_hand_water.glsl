#extension GL_ARB_texture_query_levels : enable
#extension GL_ARB_gpu_shader5 : enable

#define RENDER_GBUFFER
#define RENDER_HAND_WATER

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
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec3 blockLightColor;

    #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
        flat out float matSmooth;
        flat out float matF0;
        flat out float matSSS;
    #endif

    #ifdef PARALLAX_ENABLED
        out mat2 atlasBounds;
        out vec2 localCoord;
    #endif

    #if defined SHADOW_ENABLED
        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;

        out float shadowBias;
        out vec3 tanLightPos;
        flat out vec3 skyLightColor;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            out vec3 shadowPos[4];
            out vec3 shadowParallaxPos[4];
            out vec2 shadowProjectionSizes[4];
            out float cascadeSizes[4];
            flat out int shadowCascade;
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
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

    #if MC_VERSION >= 11700 && (defined IS_OPTIFINE || defined IRIS_FEATURE_CHUNK_OFFSET)
        uniform vec3 chunkOffset;
    #endif

    #ifdef SHADOW_ENABLED
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform vec3 shadowLightPosition;
        uniform float far;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #ifdef IS_OPTIFINE
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

            uniform mat4 gbufferProjection;
            uniform float near;

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
    #include "/lib/lighting/pbr.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;

        if (mc_Entity.x == 100.0) materialId = 1;
        else materialId = 0;

        BasicVertex(viewPos);
        PbrVertex(viewPos);

        vec2 skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
        sunColor = GetSunLightLuxColor(skyLightTemps.x, skyLightLevels.x);
        moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);
        skyLightColor = GetSkyLightLuxColor(skyLightLevels);

        blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

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
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in vec3 blockLightColor;

    #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
        flat in float matSmooth;
        flat in float matF0;
        flat in float matSSS;
    #endif

    #ifdef PARALLAX_ENABLED
        in mat2 atlasBounds;
        in vec2 localCoord;
    #endif

    #if defined SHADOW_ENABLED
        in float shadowBias;
        in vec3 tanLightPos;
        flat in vec3 skyLightColor;

        uniform vec3 sunPosition;
        uniform vec3 moonPosition;
        uniform vec3 upPosition;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            in vec3 shadowPos[4];
            in vec3 shadowParallaxPos[4];
            in vec2 shadowProjectionSizes[4];
            in float cascadeSizes[4];
            flat in int shadowCascade;
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
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
    uniform sampler2D colortex10;

    uniform mat4 shadowProjection;
    uniform ivec2 eyeBrightnessSmooth;
    uniform int heldBlockLightValue;
    uniform float viewWidth;
    uniform float viewHeight;
    
    uniform int isEyeInWater;
    uniform float rainStrength;
    uniform int moonPhase;
    uniform float near;

    uniform vec3 skyColor;
    uniform vec3 fogColor;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogMode;
    uniform int fogShape;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;

        #if SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform usampler2D shadowcolor0;
            uniform sampler2D shadowtex0;
        
            uniform float far;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                uniform isampler2D shadowcolor1;
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
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                //uniform mat4 shadowProjection;
            
                #include "/lib/shadows/basic.glsl"
                #include "/lib/shadows/basic_render.glsl"
            #endif
        #endif
    #endif

    #include "/lib/world/scattering.glsl"
    #include "/lib/lighting/blackbody.glsl"

    #ifdef VL_ENABLED
        uniform mat4 gbufferModelViewInverse;
        uniform mat4 shadowModelView;
        //uniform mat4 shadowProjection;

        #include "/lib/lighting/volumetric.glsl"
    #endif

    #ifdef PARALLAX_ENABLED
        uniform ivec2 atlasSize;

        #ifdef PARALLAX_SMOOTH
            #include "/lib/sampling/linear.glsl"
        #endif

        #include "/lib/parallax.glsl"
    #endif

    #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
        #include "/lib/lighting/directional.glsl"
    #endif

    #include "/lib/world/sky.glsl"
    #include "/lib/world/fog.glsl"
    #include "/lib/material/hcm.glsl"
    #include "/lib/material/material.glsl"
    #include "/lib/material/material_reader.glsl"

    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        #include "/lib/bsl_ssr.glsl"
    #endif
    
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/pbr.glsl"
    #include "/lib/lighting/pbr_forward.glsl"

    /* RENDERTARGETS: 4,6 */


    void main() {
        vec4 color = PbrLighting();

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            vec4 outLum = vec4(0.0);
            outLum.r = log2(luminance(color.rgb) + EPSILON);
            outLum.a = color.a;

            gl_FragData[1] = outLum;
        #endif

        color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
        gl_FragData[0] = color;
    }
#endif
