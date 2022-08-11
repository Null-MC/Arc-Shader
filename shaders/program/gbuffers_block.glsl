#extension GL_ARB_gpu_shader5 : enable

#define RENDER_GBUFFER
#define RENDER_BLOCK

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

    #ifdef PARALLAX_ENABLED
        out vec2 localCoord;
        out vec3 tanViewPos;

        #if defined SKY_ENABLED && defined SHADOW_ENABLED
            out vec3 tanLightPos;
        #endif
    #endif

    #ifdef SKY_ENABLED
        #ifdef SHADOW_ENABLED
            uniform vec3 shadowLightPosition;
        #endif
    #endif

    #ifdef AF_ENABLED
        out vec4 spriteBounds;
    #endif

    in vec4 at_tangent;

    #if defined PARALLAX_ENABLED || defined AF_ENABLED
        in vec4 mc_midTexCoord;
    #endif

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;
    uniform vec3 cameraPosition;
    
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/pbr.glsl"


    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;

        vec3 localPos = gl_Vertex.xyz;
        BasicVertex(localPos);
        
        //vec3 viewPos = (gbufferModelView * vec4(localPos, 1.0)).xyz;
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

    #ifdef PARALLAX_ENABLED
        in vec2 localCoord;
        in vec3 tanViewPos;
        
        uniform mat4 gbufferProjection;

        #if defined SKY_ENABLED && defined SHADOW_ENABLED
            in vec3 tanLightPos;
        #endif
    #endif

    #ifdef AF_ENABLED
        in vec4 spriteBounds;
    #endif

    uniform sampler2D gtexture;
    uniform sampler2D normals;
    uniform sampler2D specular;
    uniform sampler2D lightmap;

    uniform ivec2 atlasSize;

    #ifdef SKY_ENABLED
        uniform vec3 upPosition;
        uniform float wetness;
    #endif

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform float alphaTestRef;
    #endif

    #ifdef AF_ENABLED
        uniform float viewHeight;
    #endif
        
    #include "/lib/atlas.glsl"
    #include "/lib/sampling/linear.glsl"

    #ifdef SKY_ENABLED
        #include "/lib/world/porosity.glsl"
    #endif
    
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
