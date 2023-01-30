#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SHADOW

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

/*
const int shadowcolor0Format = RGBA8;
const int shadowcolor1Format = RG32UI;
*/

const bool shadowcolor0Nearest = false;
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
const bool shadowcolor0Clear = true;

const bool shadowcolor1Nearest = true;
const bool shadowcolor1Clear = true;

const bool generateShadowMipmap = true;

const bool shadowtex0Mipmap = false;
const bool shadowtex0Nearest = false;
const bool shadowHardwareFiltering0 = true;

const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;
const bool shadowHardwareFiltering1 = true;


in vec3 gLocalPos;
in vec2 gTexcoord;
//in vec2 gLmcoord;
in vec4 gColor;
flat in int gBlockId;

in vec3 gViewPos;
//in mat3 gMatShadowViewTBN;

//#ifdef RSM_ENABLED
//    flat in mat3 gMatViewTBN;
//#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat in vec2 gShadowTilePos;
#endif

uniform sampler2D gtexture;
//uniform sampler2D normals;
//uniform sampler2D specular;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelViewInverse;
uniform vec3 shadowLightPosition;
uniform int renderStage;
uniform int worldTime;
uniform int entityId;

#if MC_VERSION >= 11700 && SHADER_PLATFORM != PLATFORM_IRIS
   uniform float alphaTestRef;
#endif

#ifdef WORLD_WATER_ENABLED
    uniform vec3 cameraPosition;
    uniform float frameTimeCounter;
    uniform float rainStrength;
#endif

//#include "/lib/material/hcm.glsl"
//#include "/lib/material/material.glsl"
//#include "/lib/material/material_reader.glsl"
#include "/lib/celestial/position.glsl"

//#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && defined SSS_ENABLED
//    #include "/lib/material/default.glsl"
//#endif

#ifdef WORLD_WATER_ENABLED
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"
#endif

#ifdef PHYSICS_OCEAN
    #include "/lib/physicsMod/water.glsl"
#endif

// #ifdef RSM_ENABLED
//     #include "/lib/lighting/fresnel.glsl"
//     #include "/lib/lighting/brdf.glsl"
// #endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;


void main() {
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec2 screenCascadePos = 2.0 * (gl_FragCoord.xy / shadowMapSize - gShadowTilePos);
        if (saturate(screenCascadePos.xy) != screenCascadePos.xy) discard;
    #endif

    vec4 sampleColor;
    if (gBlockId == MATERIAL_WATER) {
        sampleColor = WATER_COLOR;
    }
    else {
        //mat2 dFdXY = mat2(dFdx(gTexcoord), dFdy(gTexcoord));
        sampleColor = texture(gtexture, gTexcoord);
        sampleColor.rgb = RGBToLinear(sampleColor.rgb * gColor.rgb);
    }

    if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
        if (sampleColor.a < alphaTestRef) discard;
        sampleColor.a = 1.0;
    }

    vec4 lightColor = sampleColor;

    if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
        lightColor.rgb = vec3(1.0);
    }

    outColor0 = lightColor;
}
