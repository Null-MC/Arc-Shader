#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_ENTITIES_TRANSLUCENT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

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

    uniform float viewHeight;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

uniform ivec2 atlasSize;
uniform vec4 entityColor;
uniform int entityId;

#ifdef SKY_ENABLED
    uniform vec3 upPosition;
    uniform float wetness;
#endif

// #if MC_VERSION >= 11700 && defined IS_OPTIFINE
//     uniform float alphaTestRef;
// #endif
    
#include "/lib/atlas.glsl"
#include "/lib/sampling/linear.glsl"

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

// #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
//     #include "/lib/lighting/directional.glsl"
// #endif

#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/basic_gbuffers.glsl"
#include "/lib/lighting/pbr_gbuffers.glsl"

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;


void main() {
    vec4 outLum = vec4(0.0);
    outLum.r = log2(luminance(color.rgb) + EPSILON);
    outLum.a = color.a;
    outColor1 = outLum;

    color.rgb = vec3(0.0);//clamp(color.rgb * exposure, vec3(0.0), vec3(65000));

    outColor0 = fuck;
}
