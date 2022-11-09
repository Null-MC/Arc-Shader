#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_TEXTURED

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 localPos;
in vec3 viewPos;
in vec3 viewNormal;
flat in float exposure;
flat in vec3 blockLightColor;

#if defined HANDLIGHT_ENABLED || CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in vec2 skyLightLevels;
    //flat in vec3 skyLightColor;
    flat in vec3 sunTransmittanceEye;

    uniform sampler2D colortex9;
    uniform usampler2D shadowcolor1;

    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform float wetness;
    uniform vec3 skyColor;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;
        uniform float frameTimeCounter;
    
        #if SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform sampler2D shadowtex0;
            uniform sampler2D shadowtex1;

            #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
                uniform sampler2DShadow shadowtex1HW;
            #endif

            #if defined SHADOW_COLOR || defined SSS_ENABLED
                uniform sampler2D shadowcolor0;
            #endif

            // #if defined SSS_ENABLED && defined SHADOW_COLOR
            //     uniform usampler2D shadowcolor1;
            // #endif
            
            uniform mat4 shadowModelView;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                flat in float cascadeSizes[4];
                flat in vec3 matShadowProjections_scale[4];
                flat in vec3 matShadowProjections_translation[4];
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                uniform mat4 shadowProjection;
            #endif

            #if defined VL_ENABLED //&& defined VL_PARTICLES
                uniform sampler2D noisetex;
            
                uniform mat4 shadowModelViewInverse;
                uniform float viewWidth;
                uniform float viewHeight;
            #endif
        #endif
    #endif
#endif

#if defined SHADOW_CONTACT || REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform mat4 gbufferProjectionInverse;
#endif

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;

uniform mat4 gbufferModelViewInverse;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int fogMode;

#if MC_VERSION >= 11700 && defined IS_OPTIFINE
    uniform float alphaTestRef;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

//#ifdef IS_OPTIFINE
    uniform float eyeHumidity;
//#endif

#include "/lib/depth.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"
#include "/lib/lighting/fresnel.glsl"

#ifdef SKY_ENABLED
    #include "/lib/world/scattering.glsl"
    #include "/lib/world/sky.glsl"
#endif

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/basic_handlight.glsl"
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    #if SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/sampling/bayer.glsl"

        #if SHADOW_PCF_SAMPLES == 12
            #include "/lib/sampling/poisson_12.glsl"
        #elif SHADOW_PCF_SAMPLES == 24
            #include "/lib/sampling/poisson_24.glsl"
        #elif SHADOW_PCF_SAMPLES == 36
            #include "/lib/sampling/poisson_36.glsl"
        #endif
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#include "/lib/world/sun.glsl"
#include "/lib/world/fog.glsl"

#if defined SKY_ENABLED && defined VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE //&& defined VL_PARTICLES
    #include "/lib/sky/clouds.glsl"
    #include "/lib/lighting/volumetric.glsl"
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/basic_forward.glsl"

/* RENDERTARGETS: 4,6 */
//out vec4 outColor0;
//out vec4 outColor1;


void main() {
    LightData lightData;
    lightData.occlusion = 1.0;
    lightData.blockLight = lmcoord.x;
    lightData.skyLight = lmcoord.y;
    lightData.geoNoL = geoNoL;
    lightData.parallaxShadow = 1.0;

    lightData.transparentScreenDepth = gl_FragCoord.z;
    lightData.opaqueScreenDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);
    lightData.transparentScreenDepthLinear = linearizeDepthFast(lightData.transparentScreenDepth, near, far);

    #ifdef SKY_ENABLED
        float worldY = localPos.y + cameraPosition.y;
        lightData.skyLightLevels = skyLightLevels;
        lightData.sunTransmittance = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);
        lightData.sunTransmittanceEye = sunTransmittanceEye;
    #endif

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0))).xyz;

        #ifdef SHADOW_DITHER
            float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
        #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                lightData.matShadowProjection[i] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                
                vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + shadowCascadePos;
                lightData.shadowTilePos[i] = GetShadowCascadeClipPos(i);
                lightData.shadowBias[i] = GetCascadeBias(lightData.geoNoL, i);

                #ifdef SHADOW_DITHER
                    lightData.shadowPos[i].xy += ditherOffset;
                #endif
            }

            lightData.opaqueShadowDepth = GetNearestOpaqueDepth(lightData, vec2(0.0), lightData.opaqueShadowCascade);
            lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData, vec2(0.0), lightData.transparentShadowCascade);

            //float minOpaqueDepth = min(lightData.shadowPos[lightData.opaqueShadowCascade].z, lightData.opaqueShadowDepth);
            //lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 4.0 * far;
            float minTransparentDepth = min(lightData.shadowPos[lightData.transparentShadowCascade].z, lightData.transparentShadowDepth);
            lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * 3.0 * far;
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            lightData.shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(lightData.shadowPos.xy);
                lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz, distortFactor);
                lightData.shadowBias = GetShadowBias(lightData.geoNoL, distortFactor);
            #else
                lightData.shadowBias = GetShadowBias(lightData.geoNoL);
            #endif

            lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;

            #ifdef SHADOW_DITHER
                lightData.shadowPos.xy += ditherOffset;
            #endif

            lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos, vec2(0.0));
            lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos, vec2(0.0));

            //float minOpaqueDepth = min(lightData.shadowPos.z, lightData.opaqueShadowDepth);
            //lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 3.0 * far;
            //float minTransparentDepth = min(lightData.shadowPos.z, lightData.transparentShadowDepth);
            lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * 3.0 * far;
        #endif
    #endif

    vec4 color = BasicLighting(lightData);

    vec4 outLuminance = vec4(0.0);
    outLuminance.r = log2(luminance(color.rgb) + EPSILON);
    outLuminance.a = color.a;
    gl_FragData[1] = outLuminance;

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    gl_FragData[0] = color;
}
