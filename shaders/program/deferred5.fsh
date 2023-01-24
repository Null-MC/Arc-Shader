#define RENDER_DEFERRED_FINAL
#define RENDER_DEFERRED
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
uniform sampler2D BUFFER_HDR_OPAQUE;
uniform sampler2D BUFFER_LUM_OPAQUE;
//uniform sampler2D lightmap;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#if SHADER_PLATFORM == PLATFORM_IRIS
    uniform sampler2D texBRDF;
#else
    uniform sampler2D colortex15;
#endif

uniform sampler2D BUFFER_SKY_LUT;
uniform sampler2D BUFFER_IRRADIANCE;

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

    #if SHADER_PLATFORM == PLATFORM_IRIS
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
        uniform sampler3D colortex14;
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
#include "/lib/sampling/erp.glsl"
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
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/scattering.glsl"

    #if SHADER_PLATFORM == PLATFORM_IRIS
        #include "/lib/sky/lightning.glsl"
    #endif
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_render.glsl"
    #include "/lib/sky/clouds.glsl"
    #include "/lib/sky/stars.glsl"
#endif

#include "/lib/world/fog_vanilla.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire.glsl"
    #include "/lib/world/fog_fancy.glsl"

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
    #include "/lib/lighting/handlight_common.glsl"
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"

/* RENDERTARGETS: 4,3 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out float outColor1;


void main() {
    ivec2 iTex = ivec2(gl_FragCoord.xy);

    #ifdef WATER_ENABLED
        if (isEyeInWater != 0) {
            outColor0 = vec4(texelFetch(BUFFER_HDR_OPAQUE, iTex, 0).rgb, 1.0);
            outColor1 = texelFetch(BUFFER_LUM_OPAQUE, iTex, 0).r;
            return;
        }
    #endif

    LightData lightData;

    lightData.opaqueScreenDepth = texelFetch(depthtex1, iTex, 0).r;
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

        lightData.skyLightLevels = skyLightLevels;
        lightData.sunTransmittanceEye = sunTransmittanceEye;
        lightData.moonTransmittanceEye = moonTransmittanceEye;

        float fragElevation = GetAtmosphereElevation(worldPos);

        #if SHADER_PLATFORM == PLATFORM_IRIS
            lightData.sunTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.x);
            lightData.moonTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.y);
        #else
            lightData.sunTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.x);
            lightData.moonTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.y);
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            vec3 dX = dFdx(localPos);
            vec3 dY = dFdy(localPos);

            vec3 shadowLocalPos = localPos;

            float viewDist = length(viewPos);
            vec3 geoNormal = normalize(cross(dX, dY));
            shadowLocalPos += geoNormal * viewDist * SHADOW_NORMAL_BIAS * max(1.0 - lightData.geoNoL, 0.0);

            vec3 shadowViewPos = (shadowModelView * vec4(shadowLocalPos, 1.0)).xyz;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                lightData.shadowPos[0] = (cascadeProjection[0] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                lightData.shadowPos[1] = (cascadeProjection[1] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                lightData.shadowPos[2] = (cascadeProjection[2] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                lightData.shadowPos[3] = (cascadeProjection[3] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                                
                lightData.shadowPos[0].xy = lightData.shadowPos[0].xy * 0.5 + shadowProjectionPos[0];
                lightData.shadowPos[1].xy = lightData.shadowPos[1].xy * 0.5 + shadowProjectionPos[1];
                lightData.shadowPos[2].xy = lightData.shadowPos[2].xy * 0.5 + shadowProjectionPos[2];
                lightData.shadowPos[3].xy = lightData.shadowPos[3].xy * 0.5 + shadowProjectionPos[3];
                
                lightData.shadowBias[0] = GetCascadeBias(lightData.geoNoL, shadowProjectionSize[0]);
                lightData.shadowBias[1] = GetCascadeBias(lightData.geoNoL, shadowProjectionSize[1]);
                lightData.shadowBias[2] = GetCascadeBias(lightData.geoNoL, shadowProjectionSize[2]);
                lightData.shadowBias[3] = GetCascadeBias(lightData.geoNoL, shadowProjectionSize[3]);

                SetNearestDepths(lightData);

                if (lightData.shadowCascade >= 0) {
                    float minOpaqueDepth = min(lightData.shadowPos[lightData.shadowCascade].z, lightData.opaqueShadowDepth);
                    lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 3.0 * far;
                }
            #else
                lightData.shadowPos = (shadowProjection * vec4(shadowViewPos, 1.0)).xyz;

                #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                    float distortFactor = getDistortFactor(lightData.shadowPos.xy);
                    lightData.shadowPos = distort(lightData.shadowPos, distortFactor);
                    lightData.shadowBias = GetShadowBias(lightData.geoNoL, distortFactor);
                #else
                    lightData.shadowBias = GetShadowBias(lightData.geoNoL);
                #endif

                lightData.shadowPos = lightData.shadowPos * 0.5 + 0.5;

                lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos.xy, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos.xy, vec2(0.0));

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
    #ifdef SKY_ENABLED
        vec3 sunColorFinalEye = lightData.sunTransmittanceEye * sunColor * max(lightData.skyLightLevels.x, 0.0);
        vec3 moonColorFinalEye = lightData.moonTransmittanceEye * moonColor * max(lightData.skyLightLevels.y, 0.0) * GetMoonPhaseLevel();
    #endif

    if (lightData.opaqueScreenDepth >= 1.0) {
        if (blindness > EPSILON) {
            color = vec3(0.0);//GetAreaFogColor();
            // color = GetVanillaSkyLuminance(viewDir);
            // float horizonFogF = 1.0 - abs(localViewDir.y);

            // vec2 scatteringF = GetVanillaSkyScattering(viewDir, lightData.skyLightLevels);
            // vec3 vlColor = RGBToLinear(fogColor) * (scatteringF.x * sunColorFinalEye + scatteringF.y * moonColorFinalEye);
            // color += vlColor * (1.0 - horizonFogF);

            // vec3 starF = GetStarLight(normalize(localViewDir));
            // starF *= 1.0 - horizonFogF;
            // color += starF * StarLumen;
        }
        else {
            #ifdef SKY_ENABLED
                color = texelFetch(BUFFER_HDR_OPAQUE, iTex, 0).rgb / exposure;
            #else
                color = GetAreaFogColor();
            #endif
        }
    }
    else {
        color = PbrLighting2(material, lightData, viewPos).rgb;
    }

    if (lightData.opaqueScreenDepth < 1.0) {
        #if defined SKY_ENABLED && !defined VL_SKY_ENABLED
            vec3 viewLightDir = normalize(shadowLightPosition);
            float VoL = dot(viewLightDir, viewDir);
            vec3 localSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
            vec4 scatteringTransmittance = GetFancyFog(localPos, localSunDir, VoL);
            color = color * scatteringTransmittance.a + scatteringTransmittance.rgb;
        #elif !defined SKY_ENABLED
            float fogFactor;
            vec3 fogColorFinal;
            GetVanillaFog(lightData, viewPos, fogColorFinal, fogFactor);
            ApplyFog(color, fogColorFinal, fogFactor);
        #endif
    }

    #ifdef SKY_ENABLED
        float minDepth = min(lightData.opaqueScreenDepth, lightData.transparentScreenDepth);

        float cloudDepthTest = CLOUD_LEVEL - (cameraPosition.y + localPos.y);
        cloudDepthTest *= sign(CLOUD_LEVEL - cameraPosition.y);

        if (HasClouds(cameraPosition, localViewDir) && (minDepth > 1.0 - EPSILON || cloudDepthTest < 0.0)) {
            vec3 cloudPos = GetCloudPosition(cameraPosition, localViewDir);

            float cloudF = GetCloudFactor(cloudPos, localViewDir, 0);
            cloudF *= max(localViewDir.y, 0.0);
            cloudF *= 1.0 - blindness;

            vec3 cloudColor = GetCloudColor(cloudPos, viewDir, skyLightLevels);
            color = mix(color, cloudColor, cloudF);
        }

        #if defined VL_SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            vec3 viewNear = viewDir * near;
            vec3 viewFar = viewDir * min(length(viewPos), far);
            vec3 vlExt = vec3(1.0);

            vec3 vlColor = GetVolumetricLighting(lightData, vlExt, viewNear, viewFar);

            color = color * vlExt + vlColor;
        #endif
    #elif defined SMOKE_ENABLED
        vec3 viewNear = viewDir * near;
        vec3 viewFar = viewDir * min(length(viewPos), fogEnd);
        vec3 vlExt = vec3(1.0);

        // vec3 viewPosPrev = (gbufferPreviousModelView * vec4(localPos + (cameraPosition - previousCameraPosition), 1.0)).xyz;
        // vec3 clipPosPrev = unproject(gbufferPreviousProjection * vec4(viewPosPrev, 1.0));
        // vec2 lightTexcoord = clipPosPrev.xy * 0.5 + 0.5;

        // vec3 lightColor = textureLod(BUFFER_HDR_PREVIOUS, lightTexcoord, 8).rgb / exposure;

        vec3 vlColor = GetVolumetricSmoke(lightData, vlExt, viewNear, viewFar);

        color = color * vlExt + vlColor;
    #endif

    outColor1 = log2(luminance(color) + EPSILON);

    color = clamp(color * exposure, vec3(0.0), vec3(65000.0));
    outColor0 = vec4(color, 1.0);
}
