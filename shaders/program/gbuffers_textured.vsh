#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_TEXTURED

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 localPos;
out vec3 viewPos;
out vec3 viewNormal;
flat out float exposure;

#ifdef HANDLIGHT_ENABLED
    flat out vec3 blockLightColor;
#endif

#ifdef SKY_ENABLED
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec2 skyLightLevels;
    //flat out vec3 skyLightColor;
    flat out vec3 sunTransmittanceEye;

    uniform sampler2D colortex9;

    uniform float eyeAltitude;
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;

        #ifdef SHADOW_PARTICLES
            #if SHADOW_TYPE != SHADOW_TYPE_NONE
                uniform mat4 shadowModelView;
                uniform mat4 shadowProjection;
                uniform float far;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                flat out float cascadeSizes[4];
                flat out vec3 matShadowProjections_scale[4];
                flat out vec3 matShadowProjections_translation[4];

                uniform float near;
            #endif
        #endif
    #endif
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

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float screenBrightness;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if defined SHADOW_ENABLED && defined SHADOW_PARTICLES
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#include "/lib/lighting/blackbody.glsl"

#ifdef SKY_ENABLED
    #include "/lib/world/sun.glsl"
    #include "/lib/world/sky.glsl"
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    localPos = gl_Vertex.xyz;
    BasicVertex(localPos);
    
    #ifdef HANDLIGHT_ENABLED
        blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;
    #endif

    #ifdef SKY_ENABLED
        skyLightLevels = GetSkyLightLevels();
        vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
        //sunColor = GetSunLightLuxColor(skyLightTemps.x, skyLightLevels.x);
        sunColor = blackbody(5500.0);
        moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);
        //skyLightColor = sunColor + moonColor; // TODO: get rid of this variable

        sunTransmittanceEye = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);// * sunColor;
    #endif

    exposure = GetExposure();
}
