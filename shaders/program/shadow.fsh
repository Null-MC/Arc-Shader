#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SHADOW

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

/*
const int shadowcolor0Format = RGBA8;
*/

const bool generateShadowMipmap = false;
const bool generateShadowColorMipmap = false;

const bool shadowcolor0Nearest = false;
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
const bool shadowcolor0Clear = true;

const bool shadowtex0Mipmap = false;
const bool shadowtex0Nearest = false;
const bool shadowHardwareFiltering0 = true;

const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;
const bool shadowHardwareFiltering1 = true;


in vec3 gLocalPos;
in vec2 gTexcoord;
in vec4 gColor;
flat in int gBlockId;

in vec3 gViewPos;

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat in vec2 gShadowTilePos;
#endif

uniform sampler2D gtexture;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelViewInverse;
uniform vec3 shadowLightPosition;
uniform int renderStage;
uniform int worldTime;
uniform int entityId;

#if MC_VERSION >= 11700
   uniform float alphaTestRef;
#endif

#ifdef WORLD_WATER_ENABLED
    uniform vec3 cameraPosition;
    uniform float frameTimeCounter;
    uniform float rainStrength;
#endif

#include "/lib/sampling/noise.glsl"
#include "/lib/celestial/position.glsl"

#ifdef WORLD_WATER_ENABLED
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"
#endif

#ifdef PHYSICS_OCEAN
    #include "/lib/physicsMod/water.glsl"
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;


void main() {
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec2 screenCascadePos = 2.0 * (gl_FragCoord.xy / shadowMapSize - gShadowTilePos);
        if (saturate(screenCascadePos.xy) != screenCascadePos.xy) discard;
    #endif

    vec4 sampleColor;
    if (gBlockId == MATERIAL_WATER) {
        sampleColor = vec4(1.0, 1.0, 1.0, 0.1);
    }
    else {
        sampleColor = texture(gtexture, gTexcoord);
        sampleColor.rgb = RGBToLinear(sampleColor.rgb * gColor.rgb);
    }

    if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
        if (sampleColor.a < alphaTestRef) discard;

        #ifdef SHADOW_COLOR
            sampleColor = vec4(1.0);
        #endif
    }

    outColor0 = sampleColor;
}
