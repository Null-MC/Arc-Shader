#define RENDER_FRAG
#define RENDER_DEFERRED
#define RENDER_AO

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;

#if defined SKY_ENABLED && defined SHADOW_ENABLED && defined SHADOW_BLUR && SHADOW_TYPE != SHADOW_TYPE_NONE
    uniform sampler2D shadowtex0;
    uniform sampler2D shadowtex1;

    #ifdef SHADOW_COLOR
        uniform sampler2D shadowcolor0;
    #endif

    uniform mat4 gbufferModelView;
    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;
    uniform vec3 cameraPosition;
    uniform float rainStrength;
    uniform int moonPhase;
    uniform int worldTime;
    uniform float far;
#endif

#include "/lib/sampling/noise.glsl"

#if defined SKY_ENABLED && defined SHADOW_ENABLED && defined SHADOW_BLUR && SHADOW_TYPE != SHADOW_TYPE_NONE
    #include "/lib/matrix.glsl"
    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/lighting/light_data.glsl"
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"

    #include "/lib/sampling/ign.glsl"
    #include "/lib/shadows/common.glsl"

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
#endif


/* RENDERTARGETS: 10 */
layout(location = 0) out vec4 outColor0;

float SampleOcclusion(const in vec2 tcoord, const in vec2 uv, const in vec3 viewPos, const in vec3 cnorm) {
    vec2 sampleTex = tcoord + uv;
    vec2 viewSize = vec2(viewWidth, viewHeight);
    float sampleClipDepth = texelFetch(depthtex0, ivec2(sampleTex * viewSize), 0).r;
    vec3 sampleClipPos = vec3(sampleTex, sampleClipDepth) * 2.0 - 1.0;
    vec3 sampleViewPos = unproject(gbufferProjectionInverse * vec4(sampleClipPos, 1.0));

    vec3 diff = sampleViewPos - viewPos;
    float l = length(diff);
    vec3 v = diff / (l+1.0);
    float d = l * SSAO_SCALE;
    float ao = max(dot(cnorm, v) - SSAO_BIAS, 0.0) * rcp(1.0 + d);
    return ao * smoothstep(SSAO_MAX_DIST, SSAO_MAX_DIST * 0.5, l);
}

float GetSpiralOcclusion(const in vec2 uv, const in vec3 viewPos, const in vec3 viewNormal, const in float rad) {
    const float goldenAngle = 2.4;
    const float inv = rcp(SSAO_SAMPLES);

    float rotatePhase = hash12(uv*100.0) * 6.28;
    float rStep = inv * rad;
    float radius = 0.0;
    vec2 spiralUV;

    float ao = 0.0;
    for (int i = 0; i < SSAO_SAMPLES; i++) {
        spiralUV.x = sin(rotatePhase);
        spiralUV.y = cos(rotatePhase);
        radius += rStep;

        ao += SampleOcclusion(uv, spiralUV * radius, viewPos, viewNormal);
        rotatePhase += goldenAngle;
    }

    return ao * inv;
}

void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 itexFull = ivec2(texcoord * viewSize);

    float clipDepth = texelFetch(depthtex0, itexFull, 0).r;
    vec3 lightColor = vec3(1.0);
    float occlusion = 1.0;

    if (clipDepth < 1.0) {
        vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;
        vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

        #if defined SHADOW_ENABLED && defined SHADOW_BLUR && SHADOW_TYPE != SHADOW_TYPE_NONE
            LightData lightData;

            vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

            vec3 dX = dFdx(localPos);
            vec3 dY = dFdy(localPos);
            vec3 geoNormal = normalize(cross(dX, dY));

            uint gbufferData = texelFetch(BUFFER_DEFERRED, itexFull, 0).a;
            lightData.geoNoL = unpackUnorm4x8(gbufferData).z * 2.0 - 1.0;

            float viewDist = length(localPos);
            localPos += geoNormal * viewDist * SHADOW_NORMAL_BIAS * max(1.0 - lightData.geoNoL, 0.0);

            #ifndef IRIS_FEATURE_SSBO
                mat4 shadowModelViewEx = BuildShadowViewMatrix();
            #endif

            vec3 shadowViewPos = (shadowModelViewEx * vec4(localPos, 1.0)).xyz;

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
                #ifndef IRIS_FEATURE_SSBO
                    mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
                #endif

                lightData.shadowPos = (shadowProjectionEx * vec4(shadowViewPos, 1.0)).xyz;

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

                //lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.transparentShadowDepth, 0.0) * ShadowMaxDepth;
            #endif

            lightColor *= step(EPSILON, lightData.geoNoL);

            // #if defined WORLD_CLOUDS_ENABLED && defined SHADOW_CLOUD
            //     vec3 worldPos = localPos + cameraPosition;
            //     float cloudF = GetCloudFactor(worldPos, localLightDir, 4.0);
            //     float cloudShadow = 1.0 - cloudF;
            //     lightColor *= (0.2 + 0.8 * cloudShadow);
            // #endif

            #ifdef SHADOW_COLOR
                #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                    if (lightData.shadowPos[lightData.shadowCascade].z - lightData.transparentShadowDepth > lightData.shadowBias[lightData.shadowCascade])
                        lightColor *= GetShadowColor(lightData.shadowPos[lightData.shadowCascade].xy);
                #else
                    if (lightData.shadowPos.z - lightData.transparentShadowDepth > lightData.shadowBias)
                        lightColor *= GetShadowColor(lightData.shadowPos.xy);
                #endif
            #endif

            lightColor *= GetShadowing(lightData);
        #endif

        #if AO_TYPE == 2
            uint deferredNormal = texelFetch(BUFFER_DEFERRED, itexFull, 0).g;
            vec3 viewNormal = unpackUnorm4x8(deferredNormal).xyz;
            viewNormal = normalize(viewNormal * 2.0 - 1.0);
            
            //float rad = SSAO_RADIUS / max(-viewPos.z, 1.0);
            float rad = SSAO_RADIUS / (length(viewPos) + 1.0);

            occlusion = GetSpiralOcclusion(texcoord, viewPos, viewNormal, rad);
            occlusion = max(1.0 - occlusion * SSAO_INTENSITY, 0.0);
        #endif
    }

    outColor0 = vec4(lightColor, occlusion);
}
