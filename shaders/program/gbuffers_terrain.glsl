#extension GL_ARB_gpu_shader5 : enable

#define RENDER_GBUFFER
#define RENDER_TERRAIN

#ifdef RENDER_VERTEX
    out vec2 lmcoord;
    out vec2 texcoord;
    out vec4 glcolor;
    out vec3 viewPos;
    out vec3 viewNormal;
    out float geoNoL;
    out mat3 matTBN;
    out vec3 tanViewPos;

    #ifdef PARALLAX_ENABLED
        out mat2 atlasBounds;
        out vec2 localCoord;
    #endif

    #ifdef SHADOW_ENABLED
        out vec3 tanLightPos;

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

    in vec4 mc_Entity;
    in vec3 vaPosition;
    in vec4 at_tangent;
    in vec3 at_midBlock;

    #if defined PARALLAX_ENABLED || defined AF_ENABLED
        in vec4 mc_midTexCoord;
    #endif

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;
    uniform vec3 cameraPosition;

    #ifdef ANIM_USE_WORLDTIME
        uniform int worldTime;
    #else
        uniform float frameTimeCounter;
    #endif

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform vec3 chunkOffset;
    #endif

    #include "/lib/world/waving.glsl"

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

    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/pbr.glsl"


    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;

        mat3 matViewTBN;
        BasicVertex(matViewTBN);
        PbrVertex(matViewTBN);
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

    #ifdef PARALLAX_ENABLED
        in mat2 atlasBounds;
        in vec2 localCoord;
    #endif

    #ifdef SHADOW_ENABLED
        in vec3 tanLightPos;

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

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform float alphaTestRef;
    #endif

    #ifdef AF_ENABLED
        uniform float viewHeight;

        #include "/lib/sampling/anisotropic.glsl"
    #endif

    #ifdef SHADOW_ENABLED
        uniform usampler2D shadowcolor0;
        uniform sampler2D shadowtex0;

        #if SHADOW_TYPE == 3
            uniform isampler2D shadowcolor1;
        #endif

        #ifdef SHADOW_ENABLE_HWCOMP
            #ifndef IS_OPTIFINE
                uniform sampler2DShadow shadowtex1HW;
                uniform sampler2D shadowtex1;
            #else
                uniform sampler2DShadow shadowtex1;
            #endif
        #else
            uniform sampler2D shadowtex1;
        #endif
        
        uniform vec3 shadowLightPosition;
        uniform float near;
        uniform float far;

        #if SHADOW_PCF_SAMPLES == 12
            #include "/lib/sampling/poisson_12.glsl"
        #elif SHADOW_PCF_SAMPLES == 24
            #include "/lib/sampling/poisson_24.glsl"
        #elif SHADOW_PCF_SAMPLES == 36
            #include "/lib/sampling/poisson_36.glsl"
        #endif

        //#include "/lib/depth.glsl"

        #if SHADOW_TYPE == 3
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #elif SHADOW_TYPE != 0
            uniform mat4 shadowProjection;

            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif
    #endif

    #ifdef PARALLAX_ENABLED
        uniform ivec2 atlasSize;

        #ifdef PARALLAX_SMOOTH
            #include "/lib/sampling/linear.glsl"
        #endif

        #include "/lib/parallax.glsl"
    #endif

    #ifdef DIRECTIONAL_LIGHTMAP
        #include "/lib/lighting/directional.glsl"
    #endif

    #include "/lib/lighting/material_reader.glsl"
    #include "/lib/lighting/basic_gbuffers.glsl"
    #include "/lib/lighting/pbr_gbuffers.glsl"


    void main() {
        vec4 colorMap, normalMap, specularMap, lightingMap;
        PbrLighting(colorMap, normalMap, specularMap, lightingMap);

    /* DRAWBUFFERS:0123 */
        gl_FragData[0] = colorMap;
        gl_FragData[1] = normalMap;
        gl_FragData[2] = specularMap;
        gl_FragData[3] = lightingMap;
    }
#endif
