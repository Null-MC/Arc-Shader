#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_TEXTURED

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

//in vec4 mc_midTexCoord;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 localPos;
out vec3 viewPos;
out vec3 viewNormal;
//flat out mat2 atlasBounds;
flat out float exposure;

#ifdef HANDLIGHT_ENABLED
    flat out vec3 blockLightColor;
#endif

#ifdef SKY_ENABLED
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec2 skyLightLevels;
    flat out vec3 sunTransmittanceEye;
    flat out vec3 moonTransmittanceEye;

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
                flat out vec3 matShadowProjections_scale[4];
                flat out vec3 matShadowProjections_translation[4];
                flat out float cascadeSizes[4];
                out vec3 shadowPos[4];
                out float shadowBias[4];

                uniform mat4 gbufferProjection;
                uniform float near;
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                out vec4 shadowPos;
                out float shadowBias;
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

#if SHADER_PLATFORM == PLATFORM_OPTIFINE
    // Use previous-frame matrices in OF cause bugs
    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
#endif

uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if defined SHADOW_ENABLED && defined SHADOW_PARTICLES
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
    #endif
#endif

#include "/lib/lighting/blackbody.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/sun_moon.glsl"
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
        sunColor = GetSunLuxColor();
        moonColor = GetMoonLuxColor() * GetMoonPhaseLevel();
        skyLightLevels = GetSkyLightLevels();

        sunTransmittanceEye = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);
        moonTransmittanceEye = GetMoonTransmittance(colortex9, eyeAltitude, skyLightLevels.y);
    #endif

    exposure = GetExposure();

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && defined SHADOW_PARTICLES
        vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0))).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                mat4 matShadowProjection = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                shadowPos[i] = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                
                vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;
                //lightData.shadowTilePos[i] = shadowCascadePos;

                vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjection[0].x, matShadowProjection[1].y);;
                shadowBias[i] = GetCascadeBias(geoNoL, shadowProjectionSize);
            }
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
                shadowBias = GetShadowBias(geoNoL, distortFactor);
            #else
                shadowBias = GetShadowBias(geoNoL);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
        #endif
    #endif
}
