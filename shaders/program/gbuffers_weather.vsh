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
        uniform sampler3D texSunTransmittance;
    #else
        uniform sampler3D colortex12;
    #endif

    uniform float eyeAltitude;
    uniform float rainStrength;
    uniform vec3 shadowLightPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;
    uniform float wetness;

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        //uniform mat4 gbufferModelView;
        //uniform mat4 gbufferModelViewInverse;
        //uniform vec3 shadowLightPosition;
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform float far;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            attribute vec3 at_midBlock;

            out vec3 shadowPos[4];
            out float shadowBias[4];

            #if SHADER_PLATFORM == PLATFORM_OPTIFINE
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferPreviousModelView;
            #endif

            uniform mat4 gbufferProjection;
            uniform float near;
        #else
            out vec3 shadowPos;
            out float shadowBias;
        #endif
    #endif
#endif

uniform float screenBrightness;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int worldTime;

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

#include "/lib/matrix.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/hillaire_common.glsl"
#include "/lib/celestial/position.glsl"

#if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    #include "/lib/shadows/common.glsl"

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
    #else
        #include "/lib/shadows/basic.glsl"
    #endif
#endif

#include "/lib/celestial/transmittance.glsl"
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
    moonColor = GetMoonLuxColor();// * GetMoonPhaseLevel();
    skyLightLevels = GetSkyLightLevels();
    float eyeElevation = GetScaledSkyHeight(eyeAltitude);
    
    #if SHADER_PLATFORM == PLATFORM_IRIS
        sunTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.x);
        moonTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.y);
    #else
        sunTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.x);
        moonTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.y);
    #endif

    exposure = GetExposure();

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #ifndef IRIS_FEATURE_SSBO
            mat4 shadowModelViewEx = BuildShadowViewMatrix();
        #endif
    
        vec3 shadowViewPos = (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0)).xyz;
        shadowViewPos = (shadowModelViewEx * vec4(shadowViewPos.xyz, 1.0)).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                shadowPos[i] = (cascadeProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowProjectionPos[i];
                
                shadowBias[i] = GetCascadeBias(geoNoL, shadowProjectionSize[i]);
            }
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            shadowPos = (shadowProjection * vec4(shadowViewPos, 1.0)).xyz;

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos = distort(shadowPos, distortFactor);
                shadowBias = GetShadowBias(geoNoL, distortFactor);
            #else
                shadowBias = GetShadowBias(geoNoL);
            #endif

            shadowPos = shadowPos * 0.5 + 0.5;
        #endif
    #endif
}
