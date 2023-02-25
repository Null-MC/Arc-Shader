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

#ifndef IRIS_FEATURE_SSBO
    flat out float sceneExposure;

    #ifdef SKY_ENABLED
        flat out vec2 skyLightLevels;

        flat out vec3 skySunColor;
        flat out vec3 sunTransmittanceEye;

        #ifdef WORLD_MOON_ENABLED
            flat out vec3 skyMoonColor;
            flat out vec3 moonTransmittanceEye;
        #endif
    #endif

    #ifdef HANDLIGHT_ENABLED
        flat out vec3 blockLightColor;
    #endif
#endif

#if defined HANDLIGHT_ENABLED || CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    uniform sampler3D TEX_SUN_TRANSMIT;

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

            #ifndef IS_IRIS
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

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/scene.glsl"
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

#ifndef IRIS_FEATURE_SSBO
    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    BasicVertex(localPos);

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
            #ifndef IRIS_FEATURE_SSBO
                mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
            #endif

            shadowPos = (shadowProjectionEx * vec4(shadowViewPos, 1.0)).xyz;

            float distortFactor = getDistortFactor(shadowPos.xy);
            //shadowPos = distort(shadowPos, distortFactor) * 0.5 + 0.5;
            shadowPos = shadowPos * 0.5 + 0.5;
            shadowBias = GetShadowBias(geoNoL, distortFactor);
        #endif
    #endif

    #ifndef IRIS_FEATURE_SSBO
        sceneExposure = GetExposure();
    
        #ifdef HANDLIGHT_ENABLED
            blockLightColor = blackbody(BLOCKLIGHT_TEMP);
        #endif

        #ifdef SKY_ENABLED
            float eyeElevation = GetScaledSkyHeight(eyeAltitude);
            skyLightLevels = GetSkyLightLevels();

            skySunColor = GetSunColor();
            
            sunTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.x);

            #ifdef WORLD_MOON_ENABLED
                skyMoonColor = GetMoonColor();
            
                moonTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.y);
            #endif
        #endif
    #endif
}
