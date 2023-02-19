#define RENDER_DEFERRED_FINAL
#define RENDER_DEFERRED
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

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

#ifdef SKY_ENABLED
    uniform sampler2D BUFFER_SKY_LUT;
    uniform sampler2D BUFFER_IRRADIANCE;

    #ifdef IS_IRIS
        uniform sampler3D texSunTransmittance;
        uniform sampler3D texMultipleScattering;
    #else
        uniform sampler3D colortex12;
        uniform sampler3D colortex13;
    #endif

    //#ifdef SHADOW_ENABLED
    //    flat in vec3 skyLightColor;
    //#endif

    #ifdef SHADOW_COLOR
        uniform sampler2D BUFFER_DEFERRED2;
        //uniform sampler2D shadowcolor0;
    #endif

    #if defined SHADOW_COLOR || defined SSS_ENABLED
        uniform sampler2D shadowcolor0;
    #endif
#endif

uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D BUFFER_HDR_OPAQUE;
uniform sampler2D BUFFER_LUM_OPAQUE;
uniform sampler3D TEX_CLOUD_NOISE;
uniform sampler2D TEX_BRDF;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;

#if AO_TYPE == AO_TYPE_SS
    uniform sampler2D BUFFER_GI_AO;
#endif

#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    #ifdef SHADOW_BLUR
        uniform sampler2D BUFFER_SHADOW;
    #endif

    #if defined SSS_ENABLED && defined SSS_BLUR
        uniform sampler2D colortex1;
    #endif
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

    #ifdef IS_IRIS
        uniform bool firstPersonCamera;
        uniform vec3 eyePosition;
    #endif
#endif

#ifdef SKY_ENABLED
    uniform vec3 skyColor;
    uniform float rainStrength;
    uniform float wetness;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform int moonPhase;

    uniform vec3 shadowLightPosition;

    #ifdef IS_IRIS
        uniform vec4 lightningBoltPosition;
    #endif

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        uniform sampler2D shadowtex0;
        uniform sampler2D shadowtex1;
        //uniform usampler2D shadowcolor1;

        uniform mat4 shadowProjection;
        uniform mat4 shadowModelView;
        uniform mat4 shadowModelViewInverse;

        #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
            uniform sampler2DShadow shadowtex1HW;
        #endif
    #endif
#endif

#if defined IRIS_FEATURE_SSBO && defined LIGHT_COLOR_ENABLED && (!defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE)
    uniform sampler2D shadowtex0;
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;
uniform vec3 waterScatterColor;
uniform vec3 waterAbsorbColor;
uniform float waterFogDistSmooth;

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/scene.glsl"
    #include "/lib/ssbo/vogel_disk.glsl"

    #ifdef LIGHT_COLOR_ENABLED
        #include "/lib/ssbo/lighting.glsl"
    #endif
#endif

#include "/lib/depth.glsl"
#include "/lib/matrix.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/sampling/erp.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/fresnel.glsl"
#include "/lib/lighting/brdf.glsl"

//#if AO_TYPE == AO_TYPE_SS || (defined RSM_ENABLED && defined RSM_UPSCALE)
    #include "/lib/sampling/bilateral_gaussian.glsl"
//#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/scattering.glsl"

    #ifdef IS_IRIS
        #include "/lib/sky/lightning.glsl"
    #endif
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_render.glsl"
    #include "/lib/sky/clouds.glsl"
    #include "/lib/sky/stars.glsl"
#endif

#include "/lib/world/fog_vanilla.glsl"
#include "/lib/lighting/basic.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire.glsl"
    #include "/lib/world/fog_fancy.glsl"

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/sampling/ign.glsl"
        #include "/lib/shadows/common.glsl"

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #else
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif

        #if defined SKY_VL_ENABLED || defined WATER_VL_ENABLED
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

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/handlight_common.glsl"
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"

/* RENDERTARGETS: 4,3 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out float outColor1;


void main() {
    ivec2 iTex = ivec2(gl_FragCoord.xy);

    //outColor0 = vec4(textureLod(colortex1, texcoord, 0).rrr, 1.0);
    //return;

    #ifdef WORLD_WATER_ENABLED
        if (isEyeInWater != 0) {
            outColor0 = vec4(texelFetch(BUFFER_HDR_OPAQUE, iTex, 0).rgb, 1.0);
            outColor1 = texelFetch(BUFFER_LUM_OPAQUE, iTex, 0).r;
            return;
        }
    #endif

    LightData lightData;

    lightData.opaqueScreenDepth = texelFetch(depthtex1, iTex, 0).r;

    float handClipDepth = texelFetch(depthtex2, iTex, 0).r;
    if (handClipDepth > lightData.opaqueScreenDepth) {
        lightData.opaqueScreenDepth = lightData.opaqueScreenDepth * 2.0 - 1.0;
        lightData.opaqueScreenDepth /= MC_HAND_DEPTH;
        lightData.opaqueScreenDepth = lightData.opaqueScreenDepth * 0.5 + 0.5;
    }

    lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);

    lightData.transparentScreenDepth = 1.0;
    lightData.transparentScreenDepthLinear = far;

    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec3 clipPos = vec3(texcoord, lightData.opaqueScreenDepth) * 2.0 - 1.0;
    vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));
    vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 worldPos = cameraPosition + localPos;
    vec3 localViewDir = normalize(localPos);
    vec3 viewDir = normalize(viewPos);

    vec3 dX = dFdx(localPos);
    vec3 dY = dFdy(localPos);
    lightData.geoNormal = normalize(cross(dX, dY));

    PbrMaterial material;
    vec3 color;

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
        float fragElevation = GetAtmosphereElevation(worldPos);

        #ifdef IS_IRIS
            lightData.sunTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.x);
        #else
            lightData.sunTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.x);
        #endif

        #ifdef WORLD_MOON_ENABLED
            #ifdef IS_IRIS
                lightData.moonTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.y);
            #else
                lightData.moonTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.y);
            #endif
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            float viewDist = length(viewPos);
            float bias = viewDist * SHADOW_NORMAL_BIAS * max(1.0 - lightData.geoNoL, 0.0);
            vec3 shadowLocalPos = localPos + lightData.geoNormal * bias;

            #ifndef IRIS_FEATURE_SSBO
                mat4 shadowModelViewEx = BuildShadowViewMatrix();
            #endif

            vec3 shadowViewPos = (shadowModelViewEx * vec4(shadowLocalPos, 1.0)).xyz;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos = GetCascadeShadowPosition(shadowViewPos, lightData.shadowCascade);
                
                lightData.shadowPos[lightData.shadowCascade] = shadowPos;
                lightData.shadowBias[lightData.shadowCascade] = GetCascadeBias(lightData.geoNoL, shadowProjectionSize[lightData.shadowCascade]);

                if (lightData.shadowCascade >= 0) {
                    lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos[lightData.shadowCascade].xy, vec2(0.0));
                    lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos[lightData.shadowCascade].xy, vec2(0.0));
                    
                    float minOpaqueDepth = min(lightData.shadowPos[lightData.shadowCascade].z, lightData.opaqueShadowDepth);
                    lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * (3.0 * far);
                }
                else {
                    lightData.opaqueShadowDepth = 1.0;
                    lightData.transparentShadowDepth = 1.0;
                    lightData.waterShadowDepth = 0.0;
                }
            #else
                #ifndef IRIS_FEATURE_SSBO
                    mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
                #endif

                lightData.shadowPos = (shadowProjectionEx * vec4(shadowViewPos, 1.0)).xyz;

                float distortFactor = getDistortFactor(lightData.shadowPos.xy);
                //lightData.shadowPos = distort(lightData.shadowPos, distortFactor);
                lightData.shadowBias = GetShadowBias(lightData.geoNoL, distortFactor);

                vec2 shadowPosD = distort(lightData.shadowPos.xy) * 0.5 + 0.5;

                lightData.shadowPos = lightData.shadowPos * 0.5 + 0.5;

                lightData.opaqueShadowDepth = SampleOpaqueDepth(shadowPosD.xy, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(shadowPosD.xy, vec2(0.0));

                lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.transparentShadowDepth, 0.0) * (2.0 * far);
            #endif
        #endif

        vec3 localSunDir = GetSunLocalDir();
    #endif

    if (lightData.opaqueScreenDepth >= 1.0) {
        if (blindness > EPSILON) {
            color = vec3(0.0);
        }
        else {
            #ifdef SKY_ENABLED
                #ifdef WORLD_END
                    color = GetFancySkyLuminance(cameraPosition.y, localViewDir, 0);

                    if (localViewDir.y > 0.0) {
                        float starHorizonFogF = 1.0 - abs(localViewDir.y);
                        vec3 starF = GetStarLight(localViewDir);
                        starF *= 1.0 - starHorizonFogF;
                        color += starF * StarLumen;
                    }

                    color += GetSunWithBloom(localViewDir, localSunDir) * sunTransmittanceEye * skySunColor * SunLux;
                #else
                    color = texelFetch(BUFFER_HDR_OPAQUE, iTex, 0).rgb / sceneExposure;
                #endif
            #else
                color = GetAreaFogColor();
            #endif
        }
    }
    else {
        color = PbrLighting2(material, lightData, viewPos).rgb;
    }

    #ifdef SKY_ENABLED
        vec3 localLightDir = GetShadowLightLocalDir();
        float VoL = dot(localLightDir, localViewDir);
    #endif

    if (lightData.opaqueScreenDepth >= 1.0) {
        #if defined SKY_ENABLED && !defined SKY_VL_ENABLED
            vec4 scatteringTransmittance = GetFancyFog(localPos, localSunDir, VoL);
            color = color * scatteringTransmittance.a + scatteringTransmittance.rgb;
        // #elif !defined SKY_ENABLED
        //     float fogFactor;
        //     vec3 fogColorFinal;
        //     GetVanillaFog(lightData, viewPos, fogColorFinal, fogFactor);
        //     ApplyFog(color, fogColorFinal, fogFactor);
        #endif
    }

    #ifdef SKY_ENABLED
        #if defined WORLD_CLOUDS_ENABLED && SKY_CLOUD_LEVEL > 0
            float minDepth = min(lightData.opaqueScreenDepth, lightData.transparentScreenDepth);

            float cloudDepthTest = SKY_CLOUD_LEVEL - (cameraPosition.y + localPos.y);
            cloudDepthTest *= sign(SKY_CLOUD_LEVEL - cameraPosition.y);

            if (HasClouds(cameraPosition, localViewDir) && (minDepth > 1.0 - EPSILON || cloudDepthTest < 0.0)) {
                vec3 cloudPos = GetCloudPosition(cameraPosition, localViewDir);
                float cloudF = GetCloudFactor(cloudPos, localViewDir, 0);
                cloudF = smoothstep(0.0, 0.6, cloudF);

                cloudF *= 1.0 - blindness;
                vec3 cloudColor = GetCloudColor(cloudPos, localViewDir, skyLightLevels);

                #if !(defined SKY_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE)
                    vec4 scatteringTransmittance = GetFancyFog(cloudPos - cameraPosition, localSunDir, VoL);
                    cloudColor = cloudColor * scatteringTransmittance.a + scatteringTransmittance.rgb;
                #endif

                color = mix(color, cloudColor, cloudF);
            }
        #endif

        #if defined SKY_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            vec3 vlScatter, vlExt;
            GetVolumetricLighting(vlScatter, vlExt, localViewDir, near, min(length(viewPos) - 0.05, far));
            color = color * vlExt + vlScatter;
        #endif
    #else
        #ifdef SMOKE_ENABLED
            vec3 viewNear = viewDir * near;
            vec3 viewFar = viewDir * min(length(viewPos), fogEnd);
            vec3 vlExt = vec3(1.0);

            // vec3 viewPosPrev = (gbufferPreviousModelView * vec4(localPos + (cameraPosition - previousCameraPosition), 1.0)).xyz;
            // vec3 clipPosPrev = unproject(gbufferPreviousProjection * vec4(viewPosPrev, 1.0));
            // vec2 lightTexcoord = clipPosPrev.xy * 0.5 + 0.5;

            // vec3 lightColor = textureLod(BUFFER_HDR_PREVIOUS, lightTexcoord, 8).rgb / sceneExposure;

            vec3 vlColor = GetVolumetricSmoke(lightData, vlExt, viewNear, viewFar);

            color = color * vlExt + vlColor;
        #else
            float fogFactor;
            vec3 fogColorFinal;
            GetVanillaFog(lightData, viewPos, fogColorFinal, fogFactor);
            ApplyFog(color, fogColorFinal, fogFactor);
        #endif
    #endif

    outColor1 = log2(luminance(color) + EPSILON);

    color = clamp(color * sceneExposure, vec3(0.0), vec3(65000.0));
    outColor0 = vec4(color, 1.0);
}
