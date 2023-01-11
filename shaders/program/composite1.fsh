#define RENDER_COMPOSITE_FINAL
#define RENDER_COMPOSITE
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
flat in float exposure;
flat in vec3 blockLightColor;

#ifdef SKY_ENABLED
    flat in vec2 skyLightLevels;
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in vec3 sunTransmittanceEye;
    flat in vec3 moonTransmittanceEye;

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
        uniform sampler3D texMultipleScattering;
    #else
        uniform sampler3D colortex11;
        uniform sampler3D colortex12;
    #endif

    //#ifdef SHADOW_ENABLED
    //    flat in vec3 skyLightColor;
    //#endif

    #ifdef SHADOW_COLOR
        uniform sampler2D BUFFER_DEFERRED2;
        //uniform sampler2D shadowcolor0;
    #endif

    #ifdef RSM_ENABLED
        uniform sampler2D BUFFER_RSM_COLOR;
    #endif

    #if defined SHADOW_COLOR || defined SSS_ENABLED
        uniform sampler2D shadowcolor0;
    #endif

    // #if (defined RSM_ENABLED && defined RSM_UPSCALE) || (defined SSS_ENABLED && defined SHADOW_COLOR)
    //     uniform usampler2D shadowcolor1;
    // #endif
#endif

#if AO_TYPE == AO_TYPE_SS
    uniform sampler2D BUFFER_AO;
#endif

uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D BUFFER_LUM_OPAQUE;
uniform sampler2D BUFFER_HDR_OPAQUE;
uniform sampler2D BUFFER_LUM_TRANS;
uniform sampler2D BUFFER_HDR_TRANS;
//uniform sampler2D lightmap;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#if SHADER_PLATFORM == PLATFORM_IRIS
    uniform sampler2D texBRDF;
#else
    uniform sampler2D colortex14;
#endif

#if ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
    uniform sampler2D BUFFER_SKY_LUT;
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
    uniform vec3 previousCameraPosition;

    uniform sampler2D BUFFER_HDR_PREVIOUS;
    uniform sampler2D BUFFER_DEPTH_PREV;
#endif

#if !defined SKY_ENABLED && defined SMOKE_ENABLED
    uniform sampler2D BUFFER_BLOOM;
#endif

uniform float frameTimeCounter;
uniform int worldTime;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

uniform int fogMode;
uniform int fogShape;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;

#ifdef HANDLIGHT_ENABLED
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    uniform vec3 skyColor;
    uniform float rainStrength;
    uniform float wetness;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform int moonPhase;

    uniform vec3 shadowLightPosition;

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform vec4 lightningBoltPosition;
    #endif

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        uniform sampler2D shadowtex0;
        uniform sampler2D shadowtex1;
        uniform usampler2D shadowcolor1;

        uniform mat4 shadowProjection;
        uniform mat4 shadowModelView;
        uniform mat4 shadowModelViewInverse;

        #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
            uniform sampler2DShadow shadowtex1HW;
        #endif

        // #if defined SSS_ENABLED || (defined RSM_ENABLED && defined RSM_UPSCALE)
        //     uniform usampler2D shadowcolor1;
        // #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            flat in float cascadeSizes[4];
            flat in vec3 matShadowProjections_scale[4];
            flat in vec3 matShadowProjections_translation[4];
        #endif

        // #ifdef SHADOW_CONTACT
        //     uniform mat4 gbufferProjection;
        // #endif

        #if defined RSM_ENABLED && defined RSM_UPSCALE
            uniform sampler2D BUFFER_RSM_DEPTH;
            //uniform usampler2D shadowcolor1;

            uniform mat4 shadowProjectionInverse;
        #endif
    #endif
#endif

#if defined VL_SKY_ENABLED || defined VL_WATER_ENABLED || defined SMOKE_ENABLED
    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texCloudNoise;
    #else
        uniform sampler3D colortex13;
    #endif
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;
uniform vec3 waterScatterColor;
uniform vec3 waterAbsorbColor;
uniform float waterFogDistSmooth;

#include "/lib/depth.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/fresnel.glsl"
#include "/lib/lighting/brdf.glsl"

#if AO_TYPE == AO_TYPE_SS || (defined RSM_ENABLED && defined RSM_UPSCALE)
    #include "/lib/sampling/bilateral_gaussian.glsl"
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/celestial_position.glsl"
    #include "/lib/sky/celestial_color.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/scattering.glsl"

    #if SHADER_PLATFORM == PLATFORM_IRIS
        #include "/lib/sky/lightning.glsl"
    #endif
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/sky/hillaire_render.glsl"
    #include "/lib/sky/clouds.glsl"
    #include "/lib/sky/stars.glsl"
#endif

#include "/lib/world/fog.glsl"

#ifdef SKY_ENABLED
    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if SHADOW_TYPE == SHADOW_TYPE_BASIC
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #elif SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #endif

        #if defined VL_SKY_ENABLED || defined VL_WATER_ENABLED
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif

    #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
        #include "/lib/shadows/contact.glsl"
    #endif
#endif

#if !defined SKY_ENABLED && defined SMOKE_ENABLED
    #include "/lib/camera/bloom.glsl"
    #include "/lib/world/smoke.glsl"
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    #include "/lib/ssr.glsl"
#endif

#if defined RSM_ENABLED && defined RSM_UPSCALE
    #include "/lib/rsm.glsl"
#endif

#include "/lib/lighting/basic.glsl"

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"

/* RENDERTARGETS: 4,3 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out float outColor1;


void main() {
    ivec2 iTex = ivec2(gl_FragCoord.xy);
    //vec3 colorFinal;
    //float lumFinal;
    vec3 final;

    LightData lightData;

    lightData.opaqueScreenDepth = texelFetch(depthtex1, iTex, 0).r;
    lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);

    lightData.transparentScreenDepth = texelFetch(depthtex0, iTex, 0).r;
    lightData.transparentScreenDepthLinear = linearizeDepthFast(lightData.transparentScreenDepth, near, far);

    vec3 clipPos = vec3(texcoord, lightData.opaqueScreenDepth) * 2.0 - 1.0;
    vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));
    vec3 viewDir = normalize(viewPos);

    #ifdef SKY_ENABLED
        lightData.skyLightLevels = skyLightLevels;
        lightData.sunTransmittanceEye = sunTransmittanceEye;
        lightData.moonTransmittanceEye = moonTransmittanceEye;

        vec3 sunColorFinalEye = sunTransmittanceEye * sunColor * max(skyLightLevels.x, 0.0);
        vec3 moonColorFinalEye = moonTransmittanceEye * moonColor * max(skyLightLevels.y, 0.0) * GetMoonPhaseLevel();
    #endif

    if (isEyeInWater == 1) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 worldPos = cameraPosition + localPos;
        vec3 localViewDir = normalize(localPos);

        PbrMaterial material;

        // SKY
        if (lightData.opaqueScreenDepth > 1.0 - EPSILON) {
            lightData.parallaxShadow = 1.0;
            lightData.skyLight = 1.0;
            lightData.blockLight = 1.0;
            lightData.occlusion = 1.0;
            lightData.geoNoL = 1.0;
        }
        else {
            uvec4 deferredData = texelFetch(BUFFER_DEFERRED, iTex, 0);
            vec4 colorMap = unpackUnorm4x8(deferredData.r);
            vec4 normalMap = unpackUnorm4x8(deferredData.g);
            vec4 specularMap = unpackUnorm4x8(deferredData.b);
            vec4 lightingMap = unpackUnorm4x8(deferredData.a);
            
            lightData.occlusion = normalMap.a;
            lightData.blockLight = lightingMap.x;
            lightData.skyLight = lightingMap.y;
            lightData.geoNoL = lightingMap.z * 2.0 - 1.0;
            lightData.parallaxShadow = lightingMap.w;
            
            PopulateMaterial(material, colorMap.rgb, normalMap, specularMap);
        }

        #ifdef SKY_ENABLED
            vec3 upDir = normalize(upPosition);

            #if SHADER_PLATFORM == PLATFORM_IRIS
                lightData.sunTransmittance = GetSunTransmittance(texSunTransmittance, worldPos.y, skyLightLevels.x);
                lightData.moonTransmittance = GetMoonTransmittance(texSunTransmittance, worldPos.y, skyLightLevels.y);
            #else
                lightData.sunTransmittance = GetSunTransmittance(colortex11, worldPos.y, skyLightLevels.x);
                lightData.moonTransmittance = GetMoonTransmittance(colortex11, worldPos.y, skyLightLevels.y);
            #endif

            #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                vec3 shadowViewPos = (shadowModelView * vec4(localPos, 1.0)).xyz;

                // #ifdef SHADOW_DITHER
                //     float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
                // #endif

                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    lightData.matShadowProjection[0] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[0], matShadowProjections_translation[0]);
                    lightData.matShadowProjection[1] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[1], matShadowProjections_translation[1]);
                    lightData.matShadowProjection[2] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[2], matShadowProjections_translation[2]);
                    lightData.matShadowProjection[3] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[3], matShadowProjections_translation[3]);
                    
                    lightData.shadowProjectionSize[0] = 2.0 / vec2(lightData.matShadowProjection[0][0].x, lightData.matShadowProjection[0][1].y);
                    lightData.shadowProjectionSize[0] = 2.0 / vec2(lightData.matShadowProjection[1][0].x, lightData.matShadowProjection[1][1].y);
                    lightData.shadowProjectionSize[0] = 2.0 / vec2(lightData.matShadowProjection[2][0].x, lightData.matShadowProjection[2][1].y);
                    lightData.shadowProjectionSize[0] = 2.0 / vec2(lightData.matShadowProjection[3][0].x, lightData.matShadowProjection[3][1].y);

                    lightData.shadowPos[0] = (lightData.matShadowProjection[0] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    lightData.shadowPos[1] = (lightData.matShadowProjection[1] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    lightData.shadowPos[2] = (lightData.matShadowProjection[2] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    lightData.shadowPos[3] = (lightData.matShadowProjection[3] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                    
                    lightData.shadowTilePos[0] = GetShadowCascadeClipPos(0);
                    lightData.shadowTilePos[1] = GetShadowCascadeClipPos(1);
                    lightData.shadowTilePos[2] = GetShadowCascadeClipPos(2);
                    lightData.shadowTilePos[3] = GetShadowCascadeClipPos(3);
                    
                    lightData.shadowPos[0].xy = lightData.shadowPos[0].xy * 0.5 + lightData.shadowTilePos[0];
                    lightData.shadowPos[1].xy = lightData.shadowPos[1].xy * 0.5 + lightData.shadowTilePos[1];
                    lightData.shadowPos[2].xy = lightData.shadowPos[2].xy * 0.5 + lightData.shadowTilePos[2];
                    lightData.shadowPos[3].xy = lightData.shadowPos[3].xy * 0.5 + lightData.shadowTilePos[3];
                    
                    lightData.shadowBias[0] = GetCascadeBias(lightData.geoNoL, lightData.shadowProjectionSize[0]);
                    lightData.shadowBias[1] = GetCascadeBias(lightData.geoNoL, lightData.shadowProjectionSize[1]);
                    lightData.shadowBias[2] = GetCascadeBias(lightData.geoNoL, lightData.shadowProjectionSize[2]);
                    lightData.shadowBias[3] = GetCascadeBias(lightData.geoNoL, lightData.shadowProjectionSize[3]);

                    // #ifdef SHADOW_DITHER
                    //     lightData.shadowPos[0].xy += ditherOffset;
                    //     lightData.shadowPos[1].xy += ditherOffset;
                    //     lightData.shadowPos[2].xy += ditherOffset;
                    //     lightData.shadowPos[3].xy += ditherOffset;
                    // #endif

                    SetNearestDepths(lightData);

                    if (lightData.opaqueShadowCascade >= 0 && lightData.transparentShadowCascade >= 0) {
                        float minOpaqueDepth = min(lightData.shadowPos[lightData.opaqueShadowCascade].z, lightData.opaqueShadowDepth);
                        lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 3.0 * far;
                    }
                #else
                    lightData.shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

                    #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                        float distortFactor = getDistortFactor(lightData.shadowPos.xy);
                        lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz, distortFactor);
                        lightData.shadowBias = GetShadowBias(lightData.geoNoL, distortFactor);
                    #else
                        lightData.shadowBias = GetShadowBias(lightData.geoNoL);
                    #endif

                    lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;

                    // #ifdef SHADOW_DITHER
                    //     lightData.shadowPos.xy += ditherOffset;
                    // #endif

                    lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos, vec2(0.0));
                    lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos, vec2(0.0));

                    #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                        const float ShadowMaxDepth = 512.0;
                    #else
                        const float ShadowMaxDepth = 256.0;
                    #endif

                    lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.transparentShadowDepth, 0.0) * ShadowMaxDepth;
                #endif
            #endif
        #endif

        if (lightData.opaqueScreenDepth < 1.0) {
            final = PbrLighting2(material, lightData, viewPos).rgb;

            // TODO: apply sky fog if beyond water
            vec3 fogColorFinal;
            float fogFactorFinal;
            GetFog(lightData, worldPos, viewPos, fogColorFinal, fogFactorFinal);

            #ifdef SKY_ENABLED
                vec2 skyScatteringF = GetVanillaSkyScattering(viewDir, skyLightLevels);

                #if !defined VL_SKY_ENABLED && ATMOSPHERE_TYPE == ATMOSPHERE_VANILLA
                    fogColorFinal += RGBToLinear(fogColor) * (
                        skyScatteringF.x * sunColorFinalEye +
                        skyScatteringF.y * moonColorFinalEye);
                #endif
            #endif

            if (lightData.transparentScreenDepth < lightData.opaqueScreenDepth)
                ApplyFog(final, fogColorFinal, fogFactorFinal);

            //lumFinal = log2(luminance(color) + EPSILON);
            //colorFinal = clamp(color * exposure, vec3(0.0), vec3(65000.0));
        }
        else {
            if (lightData.transparentScreenDepth > 1.0 - EPSILON) {
                // #ifdef SKY_ENABLED
                //     vec2 waterScatteringF = GetWaterScattering(viewDir);
                //     vec3 color = GetWaterFogColor(sunColorFinalEye, moonColorFinalEye, waterScatteringF);

                //     #if defined VL_WATER_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                //         vec3 nearPos = viewDir * near;
                //         vec3 farPos = viewDir * min(far, waterFogDistSmooth);

                //         color += GetWaterVolumetricLighting(lightData, nearPos, farPos, waterScatteringF);
                //     #endif
                // #else
                //     vec3 color = vec3(0.0);
                // #endif

                // lumFinal = log2(luminance(color) + EPSILON);
                // colorFinal = clamp(color * exposure, vec3(0.0), vec3(65000.0));
                final = vec3(0.0);
            }
            else {
                float lum = texelFetch(BUFFER_LUM_OPAQUE, iTex, 0).r;
                final = texelFetch(BUFFER_HDR_OPAQUE, iTex, 0).rgb;

                lum = max(exp2(lum) - EPSILON, 0.0);
                setLuminance(final, lum);
            }
        }
    }
    else {
        float lum = texelFetch(BUFFER_LUM_OPAQUE, iTex, 0).r;
        final = texelFetch(BUFFER_HDR_OPAQUE, iTex, 0).rgb;

        lum = max(exp2(lum) - EPSILON, 0.0);
        setLuminance(final, lum);
    }

    float lumTrans = texelFetch(BUFFER_LUM_TRANS, iTex, 0).r;
    vec4 colorTrans = texelFetch(BUFFER_HDR_TRANS, iTex, 0);
    //lumTrans = max(exp2(lumTrans) - EPSILON, 0.0);
    //setLuminance(colorTrans.rgb, lumTrans);

    final = mix(final, colorTrans.rgb / exposure, colorTrans.a);
    //lumFinal = mix(lumFinal, lumTrans, colorTrans.a);


    // vec3 final = colorFinal;
    // float lum = max(exp2(lumFinal) - EPSILON, 0.0);
    // setLuminance(final, lum);

    if (isEyeInWater == 1) {
        // TODO: get actual linear distance
        float viewDist = min(lightData.opaqueScreenDepthLinear, lightData.transparentScreenDepthLinear);

        vec3 waterExtinctionInv = WATER_ABSROPTION_RATE * (1.0 - waterAbsorbColor);
        final *= exp(-viewDist * waterExtinctionInv);

        // TODO: apply water fog
        #ifdef SKY_ENABLED
            vec3 waterSunColorEye = sunColorFinalEye * max(skyLightLevels.x, 0.0);
            vec3 waterMoonColorEye = moonColorFinalEye * max(skyLightLevels.y, 0.0);

            vec2 waterScatteringF = GetWaterScattering(viewDir);
            vec3 waterFogColor = GetWaterFogColor(waterSunColorEye, waterMoonColorEye, waterScatteringF);
        #else
            vec3 waterFogColor = vec3(0.0);
        #endif

        ApplyWaterFog(final, waterFogColor, viewDist);

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && defined VL_WATER_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            vec3 nearViewPos = viewDir * near;
            vec3 farViewPos = viewDir * min(viewDist, waterFogDistSmooth);

            final.rgb += GetWaterVolumetricLighting(lightData, nearViewPos, farViewPos, waterScatteringF);
        #endif
    }

    outColor1 = log2(luminance(final) + EPSILON);

    final = clamp(final * exposure, vec3(0.0), vec3(65000.0));
    outColor0 = vec4(final, 1.0);


    //outColor0 = vec4(colorFinal, 1.0);
    //outColor1 = lumFinal;
}
