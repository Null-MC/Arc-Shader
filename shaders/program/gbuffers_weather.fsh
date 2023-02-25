#define RENDER_WEATHER
#define RENDER_GBUFFER
#define RENDER_FRAG

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

#ifndef IRIS_FEATURE_SSBO
    flat in float sceneExposure;

    flat in vec3 blockLightColor;

    #ifdef SKY_ENABLED
        flat in vec2 skyLightLevels;

        flat in vec3 skySunColor;
        flat in vec3 sunTransmittanceEye;

        #ifdef WORLD_MOON_ENABLED
            flat in vec3 skyMoonColor;
            flat in vec3 moonTransmittanceEye;
        #endif
    #endif
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        in vec3 shadowPos[4];
        in float shadowBias[4];
    #else
        in vec3 shadowPos;
        in float shadowBias;
    #endif
#endif

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;

uniform sampler2D BUFFER_SKY_LUT;
uniform sampler2D BUFFER_IRRADIANCE;
uniform sampler3D TEX_CLOUD_NOISE;

#ifdef SKY_ENABLED
    uniform sampler2D noisetex;
    uniform usampler2D shadowcolor1;
    uniform sampler3D TEX_SUN_TRANSMIT;
    uniform sampler3D TEX_MULTI_SCATTER;

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

            #if SHADOW_TYPE != SHADOW_TYPE_CASCADED
                uniform mat4 shadowProjection;
            #endif

            #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
                uniform sampler2DShadow shadowtex1HW;
            #endif

            #if defined SHADOW_COLOR || defined SSS_ENABLED
                uniform sampler2D shadowcolor0;
            #endif

            uniform mat4 shadowModelView;
            
            #ifdef SKY_VL_ENABLED //&& defined VL_PARTICLES
                uniform mat4 shadowModelViewInverse;
                uniform float viewWidth;
                uniform float viewHeight;
            #endif
            
            #if defined SKY_VL_ENABLED || defined WATER_VL_ENABLED
                uniform mat4 gbufferProjection;
            #endif
        #endif
    #endif
#endif

uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform int worldTime;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int fogMode;

#ifdef HANDLIGHT_ENABLED
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;

    #ifdef IS_IRIS
        uniform bool firstPersonCamera;
        uniform vec3 eyePosition;
    #endif
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;
uniform vec3 waterAbsorbColor;
uniform vec3 waterScatterColor;
uniform float waterFogDistSmooth;

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/scene.glsl"
    #include "/lib/ssbo/vogel_disk.glsl"
#endif

#include "/lib/depth.glsl"
#include "/lib/matrix.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/sampling/erp.glsl"
#include "/lib/sampling/ign.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"
#include "/lib/lighting/fresnel.glsl"
#include "/lib/sky/hillaire_common.glsl"
#include "/lib/celestial/position.glsl"
#include "/lib/lighting/basic.glsl"

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/handlight_common.glsl"
    #include "/lib/lighting/basic_handlight.glsl"
#endif

#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    //#include "/lib/sampling/ign.glsl"
    #include "/lib/shadows/common.glsl"

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #else
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#include "/lib/celestial/transmittance.glsl"
#include "/lib/sky/hillaire_render.glsl"
#include "/lib/sky/hillaire.glsl"
#include "/lib/world/scattering.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/world/fog_vanilla.glsl"
#include "/lib/world/fog_fancy.glsl"
#include "/lib/sky/clouds.glsl"

#if (defined SKY_VL_ENABLED || defined WATER_VL_ENABLED) && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE //&& defined VL_PARTICLES
    #include "/lib/lighting/volumetric.glsl"
#endif

#ifdef IS_IRIS
    #include "/lib/lighting/basic_forward.glsl"
#else
    #include "/lib/lighting/basic_gbuffers.glsl"
#endif


#ifdef IS_IRIS
    /* RENDERTARGETS: 2,1 */
    layout(location = 0) out vec4 outColor0;
    layout(location = 1) out vec4 outColor1;
#else
    /* RENDERTARGETS: 0 */
    layout(location = 0) out uvec4 outColor0;
#endif

void main() {
    vec3 worldPos = cameraPosition + localPos;
    if (worldPos.y >= SKY_CLOUD_LEVEL) {discard; return;}

    #ifdef IS_IRIS
        vec4 albedo = texture(gtexture, texcoord) * glcolor;
        albedo.a *= WEATHER_OPACITY * 0.01;

        float threshold = InterleavedGradientNoise(gl_FragCoord.xy);
        if (albedo.a <= threshold) {discard; return;}

        albedo.rgb = RGBToLinear(albedo.rgb);// * glcolor.rgb);
        albedo.a = 1.0;

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
            //lightData.skyLightLevels = skyLightLevels;
            //lightData.sunTransmittanceEye = sunTransmittanceEye;
            //lightData.moonTransmittanceEye = moonTransmittanceEye;

            float fragElevation = GetAtmosphereElevation(worldPos);

            lightData.sunTransmittance = GetTransmittance(fragElevation, skyLightLevels.x);
            lightData.moonTransmittance = GetTransmittance(fragElevation, skyLightLevels.y);
        #endif

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                for (int i = 0; i < 4; i++) {
                    lightData.shadowPos[i] = shadowPos[i];
                    lightData.shadowBias[i] = shadowBias[i];
                }

                lightData.shadowCascade = GetShadowSampleCascade(shadowPos, shadowPcfSize);
                SetNearestDepths(lightData);
                //lightData.opaqueShadowDepth = GetNearestOpaqueDepth(lightData.shadowPos, vec2(0.0), lightData.shadowCascade);
                //lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData.shadowPos, vec2(0.0), lightData.shadowCascade);

                float minTransparentDepth = min(lightData.shadowPos[lightData.shadowCascade].z, lightData.transparentShadowDepth);
                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * 3.0 * far;
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                lightData.shadowPos = shadowPos;
                lightData.shadowBias = shadowBias;

                lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos.xy, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos.xy, vec2(0.0));

                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * 3.0 * far;
            #endif
        #endif

        vec4 color = BasicLighting(lightData, albedo, viewNormal);
        //color = vec4(0.0, 0.0, 1000.0, 1.0);
        //color.a = 1.0;

        vec4 outLuminance = vec4(0.0);
        outLuminance.r = log2(luminance(color.rgb) + EPSILON);
        outLuminance.a = color.a;
        outColor1 = outLuminance;

        color.rgb = clamp(color.rgb * sceneExposure, vec3(0.0), vec3(65000));
        outColor0 = vec4(color.rgb, color.a);
    #else
        mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
        
        vec4 colorMap, normalMap, specularMap, lightingMap;
        BasicLighting(dFdXY, colorMap);

        uvec4 data;
        data.r = packUnorm4x8(colorMap);
        data.g = packUnorm4x8(normalMap);
        data.b = packUnorm4x8(specularMap);
        data.a = packUnorm4x8(lightingMap);
        outColor0 = data;
    #endif
}
