#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_WEATHER

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

#if defined HANDLIGHT_ENABLED || CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    flat out vec3 sunColor;
    flat out vec3 moonColor;
    flat out vec2 skyLightLevels;
    //flat out vec3 skyLightColor;
    flat out vec3 sunTransmittanceEye;
    flat out vec3 moonTransmittanceEye;
    
    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler2D texSunTransmission;
    #else
        uniform sampler2D colortex9;
    #endif

    uniform float eyeAltitude;
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        uniform mat4 gbufferModelView;
        uniform mat4 gbufferModelViewInverse;
        uniform vec3 shadowLightPosition;
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform float far;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            attribute vec3 at_midBlock;

            flat out vec3 matShadowProjections_scale[4];
            flat out vec3 matShadowProjections_translation[4];
            flat out float cascadeSizes[4];
            out vec3 shadowPos[4];
            out float shadowBias[4];

            #if SHADER_PLATFORM == PLATFORM_OPTIFINE
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

            uniform mat4 gbufferProjection;
            uniform float near;
        #else
            out vec4 shadowPos;
            out float shadowBias;
        #endif
    #endif
#endif

uniform float screenBrightness;
uniform vec3 cameraPosition;
uniform float nightVision;
uniform float blindness;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    
    uniform float viewWidth;
    uniform float viewHeight;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
    //uniform int heldBlockLightValue;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/sun_moon.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/lighting/basic.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    localPos = gl_Vertex.xyz;
    BasicVertex(localPos);
    
    #ifdef HANDLIGHT_ENABLED
        blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;
    #endif

    sunColor = GetSunLuxColor();
    moonColor = GetMoonLuxColor() * GetMoonPhaseLevel();
    skyLightLevels = GetSkyLightLevels();
    
    #if SHADER_PLATFORM == PLATFORM_IRIS
        sunTransmittanceEye = GetSunTransmittance(texSunTransmission, eyeAltitude, skyLightLevels.x);
        moonTransmittanceEye = GetMoonTransmittance(texSunTransmission, eyeAltitude, skyLightLevels.y);
    #else
        sunTransmittanceEye = GetSunTransmittance(colortex9, eyeAltitude, skyLightLevels.x);
        moonTransmittanceEye = GetMoonTransmittance(colortex9, eyeAltitude, skyLightLevels.y);
    #endif

    exposure = GetExposure();

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0))).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                mat4 matShadowProjection = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                shadowPos[i] = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                shadowBias[i] = GetCascadeBias(geoNoL, i);
                
                vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;
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
