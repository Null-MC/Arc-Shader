#define RENDER_TEXTURED
#define RENDER_GBUFFER
#define RENDER_FRAG

//#undef PARALLAX_ENABLED
//#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 localPos;
in vec3 viewPos;
in vec3 viewNormal;
in vec3 viewTangent;
flat in float tangentW;
flat in int materialId;

#ifdef IS_IRISX
    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            in vec3 shadowPos[4];
            in float shadowBias[4];
        #elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
            in vec3 shadowPos;
            in float shadowBias;
        #endif
    #endif
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

#ifdef IS_IRISX
    uniform sampler2D depthtex1;
    uniform sampler2D noisetex;
    uniform sampler2D BUFFER_HDR_OPAQUE;
    uniform sampler2D TEX_BRDF;

    #ifdef SKY_ENABLED
        uniform sampler2D BUFFER_SKY_LUT;
        uniform sampler2D BUFFER_IRRADIANCE;
        uniform sampler3D TEX_SUN_TRANSMIT;
        uniform sampler3D TEX_MULTI_SCATTER;

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform sampler2D shadowtex0;
            uniform sampler2D shadowtex1;
            uniform usampler2D shadowcolor1;

            #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
                uniform sampler2DShadow shadowtex1HW;
            #endif

            #if defined SHADOW_COLOR || defined SSS_ENABLED
                uniform sampler2D shadowcolor0;
            #endif
        #endif
    #endif

    #if defined SKY_VL_ENABLED || defined WORLD_WATER_ENABLED
        uniform sampler3D TEX_CLOUD_NOISE;
    #endif
#else
#endif

uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform int worldTime;
uniform float far;

#if MC_VERSION >= 11700
    uniform float alphaTestRef;
#endif

#ifdef IS_IRISX
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjection;

    uniform ivec2 eyeBrightnessSmooth;
    uniform float frameTimeCounter;
    uniform int isEyeInWater;
    uniform float blindness;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform vec3 upPosition;
    uniform float near;
    //uniform float far;

    uniform vec3 waterAbsorbColor;
    uniform vec3 waterScatterColor;
    uniform float waterFogDistSmooth;

    #ifdef SKY_ENABLED
        uniform float rainStrength;
        uniform int moonPhase;
        uniform float wetness;

        #ifdef SHADOW_ENABLED
            uniform mat4 shadowModelView;
            uniform mat4 shadowModelViewInverse;
            uniform mat4 shadowProjection;
            uniform vec3 shadowLightPosition;
        #endif
    #endif

    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        uniform sampler2D BUFFER_HDR_PREVIOUS;
        uniform sampler2D BUFFER_DEPTH_PREV;

        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;
        //uniform mat4 gbufferProjection;
        uniform vec3 previousCameraPosition;
    #endif

    #ifdef HANDLIGHT_ENABLED
        uniform int heldBlockLightValue;
        uniform int heldBlockLightValue2;
        
        #ifdef IS_IRISX
            uniform bool firstPersonCamera;
            uniform vec3 eyePosition;
        #endif
    #endif
#endif

#include "/lib/sampling/ign.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"

#ifdef SKY_ENABLED
    #include "/lib/celestial/position.glsl"
#endif

#ifdef IS_IRISX
    #ifdef IRIS_FEATURE_SSBO
        #include "/lib/ssbo/scene.glsl"
        #include "/lib/ssbo/vogel_disk.glsl"
    #endif

    #include "/lib/depth.glsl"
    #include "/lib/matrix.glsl"
    #include "/lib/sampling/linear.glsl"
    #include "/lib/sampling/noise.glsl"
    #include "/lib/sampling/erp.glsl"
    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/lighting/light_data.glsl"
    #include "/lib/lighting/fresnel.glsl"
    #include "/lib/lighting/brdf.glsl"
    #include "/lib/world/fog_vanilla.glsl"

    #ifdef SKY_ENABLED
        #include "/lib/sky/hillaire_common.glsl"
        #include "/lib/celestial/transmittance.glsl"
        #include "/lib/world/sky.glsl"
        #include "/lib/world/scattering.glsl"
        #include "/lib/sky/hillaire_render.glsl"
        #include "/lib/sky/clouds.glsl"
        #include "/lib/sky/stars.glsl"
        #include "/lib/sky/hillaire.glsl"
        #include "/lib/world/fog_fancy.glsl"
        #include "/lib/lighting/basic.glsl"

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
    #endif

    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        #include "/lib/ssr.glsl"
    #endif

    #ifdef HANDLIGHT_ENABLED
        #include "/lib/lighting/handlight_common.glsl"

        #ifdef PARTICLE_PBR
            #include "/lib/lighting/pbr_handlight.glsl"
        #else
            #include "/lib/lighting/basic_handlight.glsl"
        #endif
    #endif

    #include "/lib/lighting/pbr.glsl"

    #ifdef PARTICLE_PBR
        #include "/lib/lighting/pbr_forward.glsl"
    #else
        #include "/lib/lighting/basic_forward.glsl"
    #endif
#else
    #ifdef PARTICLE_PBR
        #include "/lib/lighting/pbr_gbuffers.glsl"
    #else
        #include "/lib/lighting/basic_gbuffers.glsl"
    #endif
#endif

#ifdef IS_IRISX
    /* RENDERTARGETS: 2,1 */
    layout(location = 0) out vec4 outColor0;
    layout(location = 1) out vec4 outColor1;
#else
    /* RENDERTARGETS: 0 */
    layout(location = 0) out uvec4 outColor0;
#endif

void main() {
    #ifdef IS_IRISX
        #ifdef PARTICLE_PBR
            vec4 color = PbrLighting();
        #else
            vec4 albedo = texture(gtexture, texcoord) * glcolor;
            //albedo.a *= WEATHER_OPACITY * 0.01;
            if (albedo.a < (1.5/255.0)) {discard; return;}

            albedo.rgb = RGBToLinear(albedo.rgb);
            //albedo.a = 0.5;

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

                vec3 worldPos = cameraPosition + localPos;
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
        #endif

        vec4 outLum = vec4(0.0);
        outLum.r = log2(luminance(color.rgb) + EPSILON);
        outLum.a = color.a;
        outColor1 = outLum;

        color.rgb = clamp(color.rgb * sceneExposure, vec3(0.0), vec3(65000));
        outColor0 = color;
    #else
        vec4 colorMap, normalMap, specularMap, lightingMap;
        #ifdef PARTICLE_PBR
            PbrLighting(colorMap, normalMap, specularMap, lightingMap);
        #else
            mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));
            
            BasicLighting(dFdXY, colorMap);

            // #ifdef SHADOW_ENABLED
            //     vec3 _viewNormal = GetShadowLightViewDir();
            // #else
            //     vec3 _viewNormal = normalize(viewNormal);
            // #endif

            normalMap = vec4(0.0, 0.0, 0.0, 1.0);
            specularMap = vec4(0.0, 0.04, 0.0, 0.0);
            lightingMap = vec4(lmcoord, 1.0, 1.0);
        #endif

        uvec4 data;
        data.r = packUnorm4x8(colorMap);
        data.g = packUnorm4x8(normalMap);
        data.b = packUnorm4x8(specularMap);
        data.a = packUnorm4x8(lightingMap);
        outColor0 = data;
    #endif
}
