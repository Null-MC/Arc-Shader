#define RENDER_FRAG
#define RENDER_DEFERRED
#define RENDER_OPAQUE_FINAL

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

    uniform sampler2D colortex7;

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

#ifdef SSAO_ENABLED
    uniform sampler2D BUFFER_AO;
#endif

uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D BUFFER_LUMINANCE;
uniform sampler2D BUFFER_HDR;
uniform sampler2D colortex10;
uniform sampler2D lightmap;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
    uniform vec3 previousCameraPosition;

    uniform sampler2D BUFFER_HDR_PREVIOUS;
    uniform sampler2D BUFFER_DEPTH_PREV;
#endif

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

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

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

//#ifdef IS_OPTIFINE
    uniform float eyeHumidity;
    uniform float biomeWetness;
//#endif

#include "/lib/depth.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/fresnel.glsl"
#include "/lib/lighting/brdf.glsl"

#if defined SSAO_ENABLED || (defined RSM_ENABLED && defined RSM_UPSCALE)
    #include "/lib/sampling/bilateral_gaussian.glsl"
#endif

#ifdef SKY_ENABLED
    #include "/lib/world/sun.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/scattering.glsl"
    #include "/lib/world/porosity.glsl"
#endif

#include "/lib/world/fog.glsl"
#include "/lib/sky/clouds.glsl"
#include "/lib/sky/stars.glsl"

#ifdef SKY_ENABLED
    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #if SHADOW_PCF_SAMPLES == 12
            #include "/lib/sampling/poisson_12.glsl"
        #elif SHADOW_PCF_SAMPLES == 24
            #include "/lib/sampling/poisson_24.glsl"
        #elif SHADOW_PCF_SAMPLES == 36
            #include "/lib/sampling/poisson_36.glsl"
        #endif

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

        #ifdef VL_ENABLED
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif

    #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
        #include "/lib/shadows/contact.glsl"
    #endif
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    #include "/lib/ssr.glsl"
#endif

#if defined RSM_ENABLED && defined RSM_UPSCALE
    #if RSM_SAMPLE_COUNT == 400
        #include "/lib/sampling/rsm_400.glsl"
    #elif RSM_SAMPLE_COUNT == 200
        #include "/lib/sampling/rsm_200.glsl"
    #elif RSM_SAMPLE_COUNT == 100
        #include "/lib/sampling/rsm_100.glsl"
    #else
        #include "/lib/sampling/rsm_35.glsl"
    #endif

    #include "/lib/rsm.glsl"
#endif

#include "/lib/lighting/basic.glsl"

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out float outColor1;


void main() {
    LightData lightData;

    ivec2 iTex = ivec2(gl_FragCoord.xy);
    lightData.opaqueScreenDepth = texelFetch(depthtex1, iTex, 0).r;
    lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);

    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec3 clipPos = vec3(texcoord, lightData.opaqueScreenDepth) * 2.0 - 1.0;
    vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));
    vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 viewDir = normalize(viewPos);
    vec3 color;

    #ifdef SKY_ENABLED
        vec3 upDir = normalize(upPosition);
        float horizonFogF = 1.0 - abs(dot(viewDir, upDir));

        lightData.skyLightLevels = skyLightLevels;
        lightData.sunTransmittanceEye = sunTransmittanceEye;

        float worldY = localPos.y + cameraPosition.y;
        lightData.sunTransmittance = GetSunTransmittance(colortex7, worldY, skyLightLevels.x);

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            vec3 shadowViewPos = (shadowModelView * vec4(localPos, 1.0)).xyz;

            #ifdef SHADOW_DITHER
                float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                lightData.matShadowProjection[0] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[0], matShadowProjections_translation[0]);
                lightData.matShadowProjection[1] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[1], matShadowProjections_translation[1]);
                lightData.matShadowProjection[2] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[2], matShadowProjections_translation[2]);
                lightData.matShadowProjection[3] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[3], matShadowProjections_translation[3]);
                
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
                
                lightData.shadowBias[0] = GetCascadeBias(lightData.geoNoL, 0);
                lightData.shadowBias[1] = GetCascadeBias(lightData.geoNoL, 1);
                lightData.shadowBias[2] = GetCascadeBias(lightData.geoNoL, 2);
                lightData.shadowBias[3] = GetCascadeBias(lightData.geoNoL, 3);

                #ifdef SHADOW_DITHER
                    lightData.shadowPos[0].xy += ditherOffset;
                    lightData.shadowPos[1].xy += ditherOffset;
                    lightData.shadowPos[2].xy += ditherOffset;
                    lightData.shadowPos[3].xy += ditherOffset;
                #endif

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

                #ifdef SHADOW_DITHER
                    lightData.shadowPos.xy += ditherOffset;
                #endif

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

    // SKY
    if (lightData.opaqueScreenDepth == 1.0) {
        lightData.skyLight = 1.0;

        // vec3 viewDir = normalize(viewPos);

        if (isEyeInWater == 1) {
            vec3 waterLightColor = GetWaterScatterColor(viewDir, lightData.sunTransmittanceEye);
            color = GetWaterFogColor(viewDir, lightData.sunTransmittanceEye, waterLightColor);

            #ifdef VL_ENABLED
                vec3 nearPos = viewDir * near;
                vec3 farPos = viewDir * min(far, 2.0 * WATER_FOG_DIST);

                color += GetWaterVolumetricLighting(lightData, nearPos, farPos, waterLightColor);
            #endif

            //outColor1 = log2(luminance(color) + EPSILON);
            //color = clamp(color * exposure, 0.0, 65000.0);
        }
        else {
            #ifdef SKY_ENABLED
                color = texelFetch(BUFFER_HDR, iTex, 0).rgb / exposure;

                vec3 localDir = normalize(localPos);

                if (localDir.y > 0.0) {
                    vec3 starF = GetStarLight(localDir);
                    starF *= 1.0 - pow(horizonFogF, 12.0);
                    color += starF * StarLumen;
                }

                float cloudF = GetCloudFactor(cameraPosition, localPos);

                cloudF *= 1.0 - pow(horizonFogF, 8.0);
                color = mix(color, vec3(0.0), cloudF);

                // #if defined VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                //     vec3 viewNear = viewDir * near;
                //     vec3 viewFar = viewDir * far;

                //     vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux(); // * sunColor
                //     vec3 lightColor = GetVanillaSkyScattering(viewDir, skyLightLevels, sunColorFinal, moonColor);

                //     color += GetVolumetricLighting(lightData, viewNear, viewFar, lightColor);
                // #endif
            #else
                color = RGBToLinear(fogColor) * 100.0;
            #endif
        }
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

        //lightData.opaqueScreenDepth = texelFetch(depthtex1, iTex, 0).r;
        //lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);

        lightData.transparentScreenDepth = 0.0; // TODO: delinearize far?
        lightData.transparentScreenDepthLinear = far; // This doesn't work here!
        
        PbrMaterial material;
        PopulateMaterial(material, colorMap.rgb, normalMap, specularMap);

        color = PbrLighting2(material, lightData, viewPos).rgb;

        #ifdef SKY_ENABLED
            vec3 localViewDir = normalize(localPos);
            //vec2 pos = localPos.xz + (localViewDir.xz / localViewDir.y) * (CLOUD_PLANE_Y_LEVEL - localPos.y);
            //float cloudDist = (CLOUD_PLANE_Y_LEVEL - localPos.y) / localViewDir.y;
            vec3 cloudPos;
            cloudPos.y = CLOUD_PLANE_Y_LEVEL - (cameraPosition.y + localPos.y);
            cloudPos.xz = localPos.xz + (localPos.xz / localPos.y) * cloudPos.y;

            // TODO: this isn't working!
            if (dot(cloudPos, cloudPos) < dot(viewPos, viewPos)) {
                // TODO: move this out further so it's not duplicated above?
                float cloudF = GetCloudFactor(cameraPosition, localViewDir);
                cloudF *= 1.0 - pow(horizonFogF, 8.0);
                color = mix(color, vec3(0.0), cloudF);
            }
        #endif
    }

    #if defined SKY_ENABLED && defined VL_ENABLED
        if (isEyeInWater != 1) {
            vec3 viewNear = viewDir * near;
            vec3 viewFar = viewDir * min(length(viewPos), far);

            vec3 sunColorFinal = lightData.sunTransmittanceEye * GetSunLux(); // * sunColor
            vec3 lightColor = GetVanillaSkyScattering(viewDir, skyLightLevels, sunColorFinal, moonColor);

            color += GetVolumetricLighting(lightData, viewNear, viewFar, lightColor);
        }
    #endif

    outColor1 = log2(luminance(color) + EPSILON);

    color = clamp(color * exposure, vec3(0.0), vec3(65000.0));
    outColor0 = vec4(color, 1.0);
}
