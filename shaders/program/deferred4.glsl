#extension GL_ARB_texture_query_levels : enable
#extension GL_EXT_gpu_shader4 : enable

#define RENDER_DEFERRED
#define RENDER_OPAQUE_FINAL

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    flat out float exposure;
    flat out vec3 blockLightColor;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;

        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    #ifdef SKY_ENABLED
        flat out vec3 sunColor;
        flat out vec3 moonColor;

        uniform vec3 skyColor;

        #ifdef SHADOW_ENABLED
            flat out vec3 skyLightColor;

            uniform vec3 shadowLightPosition;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                flat out float cascadeSizes[4];
                flat out vec3 matShadowProjections_scale[4];
                flat out vec3 matShadowProjections_translation[4];

                uniform mat4 shadowModelView;
                uniform float near;
                uniform float far;

                #if MC_VERSION >= 11700 && (defined IS_OPTIFINE || defined IRIS_FEATURE_CHUNK_OFFSET)
                    uniform vec3 chunkOffset;
                #else
                    uniform mat4 gbufferModelViewInverse;
                #endif

                #ifdef IS_OPTIFINE
                    // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
                    uniform mat4 gbufferPreviousModelView;
                    uniform mat4 gbufferPreviousProjection;
                #else
                    uniform mat4 gbufferModelView;
                    uniform mat4 gbufferProjection;
                #endif

                #include "/lib/shadows/csm.glsl"
            #endif
        #endif
    #endif

    uniform float screenBrightness;
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
    uniform float blindness;
    
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #ifdef SKY_ENABLED
            vec2 skyLightLevels = GetSkyLightLevels();
            vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
            sunColor = GetSunLightLuxColor(skyLightTemps.x, skyLightLevels.x);
            moonColor = GetMoonLightLuxColor(skyLightTemps.y, skyLightLevels.y);
            //skyLightColor = GetSkyLightLuxColor(skyLightLevels);
            skyLightColor = sunColor + moonColor; // TODO: get rid of this variable

            // TODO: add lightning check
            // if (rainStrength > 0.5) {
            //     // if (all(greaterThan(skyColor, vec3(0.9)))) {
            //     //     skyLightColor = vec3(60000.0, 0.0, 0.0);
            //     // }
            //     if (dot(shadowLightPosition, shadowLightPosition) < 0.1) {
            //         skyLightColor = vec3(60000.0, 0.0, 0.0);
            //         skyLightLevels = vec2(1.0, 1.0);
            //     }
            // }

            #if defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
                cascadeSizes[0] = GetCascadeDistance(0);
                cascadeSizes[1] = GetCascadeDistance(1);
                cascadeSizes[2] = GetCascadeDistance(2);
                cascadeSizes[3] = GetCascadeDistance(3);

                GetShadowCascadeProjectionMatrix_AsParts(0, matShadowProjections_scale[0], matShadowProjections_translation[0]);
                GetShadowCascadeProjectionMatrix_AsParts(1, matShadowProjections_scale[1], matShadowProjections_translation[1]);
                GetShadowCascadeProjectionMatrix_AsParts(2, matShadowProjections_scale[2], matShadowProjections_translation[2]);
                GetShadowCascadeProjectionMatrix_AsParts(3, matShadowProjections_scale[3], matShadowProjections_translation[3]);
            #endif
        #endif

        blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

        exposure = GetExposure();
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    flat in float exposure;
    flat in vec3 blockLightColor;

    #ifdef SKY_ENABLED
        flat in vec3 sunColor;
        flat in vec3 moonColor;

        #ifdef SHADOW_ENABLED
            flat in vec3 skyLightColor;
        #endif

        #ifdef SHADOW_COLOR
            uniform sampler2D BUFFER_DEFERRED2;
            uniform sampler2D shadowcolor0;
        #endif

        #ifdef RSM_ENABLED
            uniform sampler2D BUFFER_RSM_COLOR;
        #endif
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
        uniform mat4 gbufferProjection;
        uniform vec3 previousCameraPosition;

        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelView;
    uniform vec3 cameraPosition;
    uniform vec3 upPosition;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float near;
    uniform float far;
    
    uniform int isEyeInWater;
    uniform ivec2 eyeBrightnessSmooth;

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

        #ifdef SHADOW_ENABLED
            uniform vec3 shadowLightPosition;
            uniform mat4 shadowProjection;
            uniform mat4 shadowModelView;

            #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                uniform sampler2DShadow shadowtex1HW;
            #elif defined SHADOW_ENABLE_HWCOMP
                uniform sampler2D shadowtex0;
                uniform sampler2DShadow shadowtex1;
            #else
                uniform sampler2D shadowtex1;
            #endif

            #if defined SSS_ENABLED || (defined RSM_ENABLED && defined RSM_UPSCALE)
                uniform usampler2D shadowcolor1;
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                flat in float cascadeSizes[4];
                flat in vec3 matShadowProjections_scale[4];
                flat in vec3 matShadowProjections_translation[4];
            #endif

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

    #ifdef IS_OPTIFINE
        uniform float eyeHumidity;
    #endif

    #include "/lib/depth.glsl"
    #include "/lib/sampling/linear.glsl"
    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/lighting/light_data.glsl"

    #ifdef SKY_ENABLED
        #include "/lib/world/scattering.glsl"
        #include "/lib/world/porosity.glsl"
        #include "/lib/world/sky.glsl"

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if SHADOW_PCF_SAMPLES == 12
                #include "/lib/sampling/poisson_12.glsl"
            #elif SHADOW_PCF_SAMPLES == 24
                #include "/lib/sampling/poisson_24.glsl"
            #elif SHADOW_PCF_SAMPLES == 36
                #include "/lib/sampling/poisson_36.glsl"
            #endif

            #if SHADOW_TYPE == SHADOW_TYPE_BASIC
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
    #endif

    #include "/lib/world/fog.glsl"
    #include "/lib/material/hcm.glsl"
    #include "/lib/material/material.glsl"
    #include "/lib/material/material_reader.glsl"

    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        #include "/lib/ssr.glsl"
    #endif

    #if defined RSM_ENABLED && defined RSM_UPSCALE
        #if RSM_SAMPLE_COUNT == 400
            #include "/lib/sampling/rsm_400.glsl"
        #elif RSM_SAMPLE_COUNT == 200
            #include "/lib/sampling/rsm_200.glsl"
        #else
            #include "/lib/sampling/rsm_100.glsl"
        #endif

        #include "/lib/rsm.glsl"
    #endif

    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/brdf.glsl"

    #ifdef HANDLIGHT_ENABLED
        #include "/lib/lighting/pbr_handlight.glsl"
    #endif

    #include "/lib/lighting/pbr.glsl"

    /* RENDERTARGETS: 4,6 */
    out vec4 outColor0;
    out float outColor1;


    void main() {
        ivec2 iTex = ivec2(gl_FragCoord.xy);
        float screenDepth = texelFetch(depthtex0, iTex, 0).r;
        vec3 color;

        // SKY
        if (screenDepth == 1.0) {
            #ifdef SKY_ENABLED
                color = texelFetch(BUFFER_HDR, iTex, 0).rgb;

                outColor1 = texelFetch(BUFFER_LUMINANCE, iTex, 0).r;
            #else
                color = RGBToLinear(fogColor) * 100.0;

                outColor1 = log2(luminance(color) + EPSILON);

                color = clamp(color * exposure, 0.0, 65000.0);
            #endif
        }
        else {
            uvec4 deferredData = texelFetch(BUFFER_DEFERRED, iTex, 0);
            vec4 colorMap = unpackUnorm4x8(deferredData.r);
            vec4 normalMap = unpackUnorm4x8(deferredData.g);
            vec4 specularMap = unpackUnorm4x8(deferredData.b);
            vec4 lightingMap = unpackUnorm4x8(deferredData.a);
            
            vec2 viewSize = vec2(viewWidth, viewHeight);
            vec3 clipPos = vec3(gl_FragCoord.xy / viewSize, screenDepth) * 2.0 - 1.0;
            vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

            PbrLightData lightData;
            lightData.blockLight = lightingMap.x;
            lightData.skyLight = lightingMap.y;
            lightData.geoNoL = lightingMap.z;
            lightData.occlusion = lightingMap.w;

            #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos, 1.0))).xyz;

                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    for (int i = 0; i < 4; i++) {
                        lightData.matShadowProjection[i] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                        lightData.shadowPos[i] = (lightData.matShadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                        
                        vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                        lightData.shadowPos[i].xy = lightData.shadowPos[i].xy * 0.5 + shadowCascadePos;
                    }
                #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                    lightData.shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

                    #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                        lightData.shadowPos.xyz = distort(lightData.shadowPos.xyz);
                    #endif

                    lightData.shadowPos.xyz = lightData.shadowPos.xyz * 0.5 + 0.5;
                #endif
            #endif

            PbrMaterial material;
            PopulateMaterial(material, colorMap.rgb, normalMap, specularMap);

            color = PbrLighting2(material, lightData, viewPos).rgb;

            outColor1 = log2(luminance(color) + EPSILON);

            color = clamp(color * exposure, vec3(0.0), vec3(65554.0));
        }

        outColor0 = vec4(color, 1.0);
    }
#endif
