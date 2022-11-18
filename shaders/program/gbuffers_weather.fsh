#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_WEATHER

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 localPos;
in vec3 viewPos;
in vec3 viewNormal;
in float geoNoL;
flat in float exposure;
flat in vec3 blockLightColor;

#ifdef HANDLIGHT_ENABLED
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in vec2 skyLightLevels;
    flat in vec3 sunTransmittanceEye;
    flat in vec3 moonTransmittanceEye;

    uniform sampler2D colortex9;
    uniform usampler2D shadowcolor1;
    uniform sampler2D noisetex;

    uniform float frameTimeCounter;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform float wetness;
    uniform vec3 skyColor;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;

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
                flat in vec3 matShadowProjections_scale[4];
                flat in vec3 matShadowProjections_translation[4];
                flat in float cascadeSizes[4];
                in vec3 shadowPos[4];
                in float shadowBias[4];
            #else
                in vec4 shadowPos;
                in float shadowBias;

                uniform mat4 shadowProjection;
            #endif
            
            #if defined VL_ENABLED //&& defined VL_PARTICLES
                //uniform sampler2D noisetex;

                //uniform mat4 shadowModelView;
                //uniform mat4 gbufferModelViewInverse;
                uniform mat4 shadowModelViewInverse;
                //uniform float frameTimeCounter;
                uniform float viewWidth;
                uniform float viewHeight;
            #endif
        #endif
    #endif
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

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;
uniform vec3 waterScatterColor;
uniform vec3 waterAbsorbColor;
uniform float waterFogDistSmooth;

#include "/lib/depth.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"
#include "/lib/lighting/fresnel.glsl"

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/basic_handlight.glsl"
#endif

#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    #include "/lib/sampling/bayer.glsl"
    
    #if SHADOW_PCF_SAMPLES == 12
        #include "/lib/sampling/poisson_12.glsl"
    #elif SHADOW_PCF_SAMPLES == 24
        #include "/lib/sampling/poisson_24.glsl"
    #elif SHADOW_PCF_SAMPLES == 36
        #include "/lib/sampling/poisson_36.glsl"
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #else
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#include "/lib/world/scattering.glsl"
#include "/lib/sky/sun_moon.glsl"
#include "/lib/sky/clouds.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/world/fog.glsl"

#if defined VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE //&& defined VL_PARTICLES
    #include "/lib/lighting/volumetric.glsl"
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/basic_forward.glsl"


/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;


void main() {
    float worldY = localPos.y + cameraPosition.y;
    if (worldY >= CLOUD_Y_LEVEL) {discard; return;}

    vec4 albedo = texture(gtexture, texcoord);
    if (albedo.a < (1.0/255.0)) {discard; return;}

    albedo.rgb = RGBToLinear(albedo.rgb * glcolor.rgb);
    albedo.a *= WEATHER_OPACITY * 0.01;

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
        lightData.skyLightLevels = skyLightLevels;
        lightData.sunTransmittance = GetSunTransmittance(colortex9, worldY, skyLightLevels.x);
        lightData.moonTransmittance = GetMoonTransmittance(colortex9, worldY, skyLightLevels.y);
        lightData.sunTransmittanceEye = sunTransmittanceEye;
        lightData.moonTransmittanceEye = moonTransmittanceEye;
    #endif

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #ifdef SHADOW_DITHER
            float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
        #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                lightData.shadowPos[i] = shadowPos[i];
                lightData.shadowBias[i] = shadowBias[i];
                lightData.shadowTilePos[i] = GetShadowCascadeClipPos(i);

                lightData.matShadowProjection[i] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);

                #ifdef SHADOW_DITHER
                    lightData.shadowPos[i].xy += ditherOffset;
                #endif
            }

            lightData.opaqueShadowDepth = GetNearestOpaqueDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.opaqueShadowCascade);
            lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.transparentShadowCascade);

            float minTransparentDepth = min(lightData.shadowPos[lightData.transparentShadowCascade].z, lightData.transparentShadowDepth);
            lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * 3.0 * far;
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            lightData.shadowPos = shadowPos;
            lightData.shadowBias = shadowBias;

            #ifdef SHADOW_DITHER
                lightData.shadowPos.xy += ditherOffset;
            #endif

            lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos, vec2(0.0));
            lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos, vec2(0.0));

            lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * 3.0 * far;
        #endif
    #endif

    vec4 color = BasicLighting(lightData, albedo);

    vec4 outLuminance = vec4(0.0);
    outLuminance.r = log2(luminance(color.rgb) + EPSILON);
    outLuminance.a = color.a;
    outColor1 = outLuminance;

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = color;
}
