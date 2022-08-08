#extension GL_ARB_gpu_shader5 : enable

#define RENDER_GBUFFER
#define RENDER_TERRAIN

#ifdef RENDER_VERTEX
    out vec2 lmcoord;
    out vec2 texcoord;
    out vec4 glcolor;
    out float geoNoL;
    out vec3 viewPos;
    out vec3 viewNormal;
    out vec3 viewTangent;
    flat out float tangentW;
    flat out mat2 atlasBounds;

    #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
        flat out float matSmooth;
        flat out float matF0;
        flat out float matSSS;
        flat out float matEmissive;
    #endif

    #ifdef PARALLAX_ENABLED
        out vec2 localCoord;
        out vec3 tanViewPos;

        #if defined SKY_ENABLED && defined SHADOW_ENABLED
            out vec3 tanLightPos;
        #endif
    #endif

    #ifdef SKY_ENABLED
        uniform float rainStrength;

        #ifdef SHADOW_ENABLED
        //     out float shadowBias;

        //     uniform mat4 shadowModelView;
        //     uniform mat4 shadowProjection;
            uniform vec3 shadowLightPosition;
        //     uniform float far;

        //     #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //         out vec3 shadowPos[4];
        //         //out vec3 shadowParallaxPos[4];
        //         //out vec2 shadowProjectionSizes[4];
        //         out float cascadeSizes[4];
        //         flat out int shadowCascade;

        //         #ifdef IS_OPTIFINE
        //             uniform mat4 gbufferPreviousProjection;
        //             uniform mat4 gbufferPreviousModelView;
        //         #endif

        //         uniform mat4 gbufferProjection;
        //         uniform float near;
        //     #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        //         out vec4 shadowPos;
        //         out vec4 shadowParallaxPos;
        //     #endif
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

    #if MC_VERSION >= 11700 && (defined IS_OPTIFINE || defined IRIS_FEATURE_CHUNK_OFFSET)
        uniform vec3 chunkOffset;
    #endif

    #include "/lib/world/wind.glsl"
    #include "/lib/world/waving.glsl"

    // #ifdef SHADOW_ENABLED
    //     #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    //         #include "/lib/shadows/csm.glsl"
    //         #include "/lib/shadows/csm_render.glsl"
    //     #elif SHADOW_TYPE != SHADOW_TYPE_NONE
    //         #include "/lib/shadows/basic.glsl"
    //         #include "/lib/shadows/basic_render.glsl"
    //     #endif
    // #endif

    #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
        #include "/lib/material/default.glsl"
    #endif

    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/pbr.glsl"


    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;

        vec3 localPos = gl_Vertex.xyz;
        BasicVertex(localPos);
        
        vec3 viewPos = (gbufferModelView * vec4(localPos, 1.0)).xyz;
        PbrVertex(viewPos);
    }
#endif

#ifdef RENDER_FRAG
    in vec2 lmcoord;
    in vec2 texcoord;
    in vec4 glcolor;
    in float geoNoL;
    in vec3 viewPos;
    in vec3 viewNormal;
    in vec3 viewTangent;
    flat in float tangentW;
    flat in mat2 atlasBounds;

    #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
        flat in float matSmooth;
        flat in float matF0;
        flat in float matSSS;
        flat in float matEmissive;
    #endif

    #ifdef PARALLAX_ENABLED
        in vec2 localCoord;
        in vec3 tanViewPos;

        #if defined SKY_ENABLED && defined SHADOW_ENABLED
            in vec3 tanLightPos;
        #endif
    #endif

    #ifdef SKY_ENABLED
        uniform vec3 upPosition;
        uniform float wetness;

        // #ifdef SHADOW_ENABLED
        //     in float shadowBias;

        //     uniform sampler2D shadowtex0;

        //     #ifdef SHADOW_COLOR
        //         uniform sampler2D shadowcolor0;
        //     #endif

        //     #ifdef SSS_ENABLED
        //         uniform usampler2D shadowcolor1;
        //     #endif

        //     #ifdef SHADOW_ENABLE_HWCOMP
        //         #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
        //             uniform sampler2DShadow shadowtex1HW;
        //             uniform sampler2D shadowtex1;
        //         #else
        //             uniform sampler2DShadow shadowtex1;
        //         #endif
        //     #else
        //         uniform sampler2D shadowtex1;
        //     #endif
            
        //     uniform vec3 shadowLightPosition;
        //     uniform float near;
        //     uniform float far;

        //     #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //         in vec3 shadowPos[4];
        //         in vec3 shadowParallaxPos[4];
        //         in vec2 shadowProjectionSizes[4];
        //         in float cascadeSizes[4];
        //         flat in int shadowCascade;
        //     #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        //         in vec4 shadowPos;
        //         in vec4 shadowParallaxPos;

        //         uniform mat4 shadowProjection;
        //     #endif
        // #endif
    #endif

    #ifdef AF_ENABLED
        in vec4 spriteBounds;

        uniform float viewHeight;
    #endif

    uniform sampler2D gtexture;
    uniform sampler2D normals;
    uniform sampler2D specular;
    uniform sampler2D lightmap;

    //uniform mat4 gbufferModelViewInverse; // FOR TESTING ONLY
    uniform ivec2 atlasSize;

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform float alphaTestRef;
    #endif

    #ifdef AF_ENABLED
        #include "/lib/sampling/anisotropic.glsl"
    #endif

    #include "/lib/atlas.glsl"
    #include "/lib/sampling/linear.glsl"
    #include "/lib/world/porosity.glsl"

    // #ifdef SHADOW_ENABLED
    //     #if SHADOW_PCF_SAMPLES == 12
    //         #include "/lib/sampling/poisson_12.glsl"
    //     #elif SHADOW_PCF_SAMPLES == 24
    //         #include "/lib/sampling/poisson_24.glsl"
    //     #elif SHADOW_PCF_SAMPLES == 36
    //         #include "/lib/sampling/poisson_36.glsl"
    //     #endif

    //     #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    //         #include "/lib/shadows/csm.glsl"
    //         #include "/lib/shadows/csm_render.glsl"
    //     #elif SHADOW_TYPE != SHADOW_TYPE_NONE
    //         #include "/lib/shadows/basic.glsl"
    //         #include "/lib/shadows/basic_render.glsl"
    //     #endif
    // #endif

    #ifdef PARALLAX_ENABLED
        #include "/lib/parallax.glsl"
    #endif

    #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
        #include "/lib/lighting/directional.glsl"
    #endif

    #include "/lib/material/material_reader.glsl"
    #include "/lib/lighting/basic_gbuffers.glsl"
    #include "/lib/lighting/pbr_gbuffers.glsl"

    /* RENDERTARGETS: 2,3 */
    out uvec4 outColor0;
    #if defined SHADOW_ENABLED && defined SHADOW_COLOR
        out vec3 outColor1;
    #endif


    void main() {
        vec3 shadowColorMap;
        vec4 colorMap, normalMap, specularMap, lightingMap;
        PbrLighting(colorMap, normalMap, specularMap, lightingMap, shadowColorMap);

        uvec4 data;
        data.r = packUnorm4x8(colorMap);
        data.g = packUnorm4x8(normalMap);
        data.b = packUnorm4x8(specularMap);
        data.a = packUnorm4x8(lightingMap);
        outColor0 = data;

        #if defined SHADOW_ENABLED && defined SHADOW_COLOR
            outColor1 = shadowColorMap;
        #endif
    }
#endif
