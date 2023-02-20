#define RENDER_FRAG
#define RENDER_DEFERRED
#define RENDER_AO

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;

#if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && (defined SHADOW_BLUR || (defined SSS_ENABLED && defined SSS_BLUR))
    uniform sampler2D shadowtex0;
    uniform sampler2D shadowtex1;

    #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
        uniform sampler2DShadow shadowtex1HW;
    #endif

    #ifdef SHADOW_COLOR
        uniform sampler2D shadowcolor0;
    #endif

    uniform mat4 gbufferModelView;
    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;
    uniform vec3 cameraPosition;
    //uniform float rainStrength;
    //uniform int moonPhase;
    uniform int worldTime;
    uniform float far;
#endif

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/vogel_disk.glsl"
    #include "/lib/ssbo/scene.glsl"
#endif

#include "/lib/sampling/noise.glsl"
#include "/lib/sampling/ign.glsl"

#if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && (defined SHADOW_BLUR || (defined SSS_ENABLED && defined SSS_BLUR))
    #include "/lib/matrix.glsl"
    //#include "/lib/lighting/blackbody.glsl"
    #include "/lib/lighting/light_data.glsl"
    //#include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    //#include "/lib/celestial/transmittance.glsl"

    #if defined SSS_ENABLED && defined SSS_BLUR
        #include "/lib/material/material.glsl"
        #include "/lib/material/material_reader.glsl"
    #endif

    #include "/lib/shadows/common.glsl"

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #else
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif


/* RENDERTARGETS: 9,10,1 */
#if AO_TYPE == AO_TYPE_SS
    layout(location = 0) out vec4 outGIAO;
#endif
#if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    #ifdef SHADOW_BLUR
        layout(location = 1) out vec4 outShadow;
    #endif
    #if defined SSS_ENABLED && defined SSS_BLUR
        layout(location = 2) out float outSSS;
    #endif
#endif

float SampleOcclusion(const in vec2 sampleTex, const in vec3 viewPos, const in vec3 cnorm) {
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
    const float inv = rcp(SSAO_SAMPLES);

    #ifdef IRIS_FEATURE_SSBO
        float dither = InterleavedGradientNoise(gl_FragCoord.xy);
        float angle = fract(dither) * TAU;
        float s = sin(angle), c = cos(angle);
        mat2 rotation = mat2(c, -s, s, c);
    #else
        float rotatePhase = hash12(uv*100.0) * 6.28;
    #endif

    float rStep = inv * rad;

    float radius = 0.0;
    vec2 offset;

    float ao = 0.0;
    for (int i = 0; i < SSAO_SAMPLES; i++) {
        #ifdef IRIS_FEATURE_SSBO
            offset = (rotation * ssaoDiskOffset[i]) * radius;
        #else
            offset.x = sin(rotatePhase);
            offset.y = cos(rotatePhase);
            offset *= radius;

            rotatePhase += GOLDEN_ANGLE;
        #endif

        radius += rStep;

        ao += SampleOcclusion(uv + offset, viewPos, viewNormal);
    }

    return ao * inv;
}

void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 itexFull = ivec2(texcoord * viewSize);

    float clipDepth = texelFetch(depthtex0, itexFull, 0).r;

    vec3 shadowColor = vec3(1.0);
    float occlusion = 1.0;
    float shadowF = 1.0;
    float sssF = 0.0;

    if (clipDepth < 1.0) {
        float handClipDepth = texelFetch(depthtex2, itexFull, 0).r;

        vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;

        if (handClipDepth > clipDepth)
            clipPos.z /= MC_HAND_DEPTH;

        vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

        #if AO_TYPE == AO_TYPE_SS || (defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && (defined SHADOW_BLUR || defined SSS_BLUR))
            uvec4 gbufferData = texelFetch(BUFFER_DEFERRED, itexFull, 0);
        #endif

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && (defined SHADOW_BLUR || (defined SSS_ENABLED && defined SSS_BLUR))
            LightData lightData;

            //uint gbufferLightData = texelFetch(BUFFER_DEFERRED, itexFull, 0).a;
            vec4 gbufferLightMap = unpackUnorm4x8(gbufferData.a);
            lightData.geoNoL = gbufferLightMap.z * 2.0 - 1.0;

            vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

            vec3 dX = dFdx(localPos);
            vec3 dY = dFdy(localPos);

            if (all(greaterThan(abs(dX) + abs(dY), EPSILON3))) {
                vec3 geoNormal = normalize(cross(dX, dY));

                float viewDist = length(localPos);
                localPos += geoNormal * viewDist * SHADOW_NORMAL_BIAS * max(1.0 - lightData.geoNoL, 0.0);
            }

            #ifndef IRIS_FEATURE_SSBO
                mat4 shadowModelViewEx = BuildShadowViewMatrix();
            #endif

            vec3 shadowViewPos = (shadowModelViewEx * vec4(localPos, 1.0)).xyz;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                vec3 shadowPos = GetCascadeShadowPosition(shadowViewPos, lightData.shadowCascade);
                
                lightData.shadowPos[lightData.shadowCascade] = shadowPos;
                lightData.shadowBias[lightData.shadowCascade] = GetCascadeBias(lightData.geoNoL, shadowProjectionSize[lightData.shadowCascade]);

                SetNearestDepths(lightData);

                // if (lightData.shadowCascade >= 0) {
                //     float minOpaqueDepth = min(lightData.shadowPos[lightData.shadowCascade].z, lightData.opaqueShadowDepth);
                //     lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 3.0 * far;
                // }
            #else
                #ifndef IRIS_FEATURE_SSBO
                    mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
                #endif

                lightData.shadowPos = (shadowProjectionEx * vec4(shadowViewPos, 1.0)).xyz;

                float distortFactor = getDistortFactor(lightData.shadowPos.xy);
                //lightData.shadowPos = distort(lightData.shadowPos, distortFactor);
                lightData.shadowBias = GetShadowBias(lightData.geoNoL, distortFactor);

                vec2 shadowPosD = distort(lightData.shadowPos.xy, distortFactor) * 0.5 + 0.5;

                lightData.shadowPos = lightData.shadowPos * 0.5 + 0.5;

                lightData.opaqueShadowDepth = SampleOpaqueDepth(shadowPosD, vec2(0.0));
                lightData.transparentShadowDepth = SampleTransparentDepth(shadowPosD, vec2(0.0));
            #endif

            #ifdef SHADOW_BLUR
                shadowF = gbufferLightMap.a;
                shadowF *= step(EPSILON, lightData.geoNoL);
                //shadowF *= lightData.geoNoL;

                if (shadowF > EPSILON)
                    shadowF *= GetShadowing(lightData);

                #ifdef SHADOW_COLOR
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        if (lightData.shadowPos[lightData.shadowCascade].z - lightData.transparentShadowDepth > lightData.shadowBias[lightData.shadowCascade])
                            shadowColor = GetShadowColor(lightData.shadowPos[lightData.shadowCascade].xy);
                    #else
                        if (lightData.shadowPos.z - lightData.transparentShadowDepth > lightData.shadowBias)
                            shadowColor = GetShadowColor(lightData.shadowPos.xy);
                    #endif
                #endif
            #endif

            #if defined SSS_ENABLED && defined SSS_BLUR
                //uint deferredSpecular = texelFetch(BUFFER_DEFERRED, itexFull, 0).b;
                float specularB = unpackUnorm4x8(gbufferData.b).b;
                float materialSSS = GetLabPbr_SSS(specularB);

                if (materialSSS > EPSILON)
                    sssF = GetShadowSSS(lightData, materialSSS);
            #endif
        #endif

        #if AO_TYPE == AO_TYPE_SS
            //uint deferredNormal = texelFetch(BUFFER_DEFERRED, itexFull, 0).g;
            vec3 viewNormal = unpackUnorm4x8(gbufferData.g).xyz;
            viewNormal = normalize(viewNormal * 2.0 - 1.0);
            
            //float rad = SSAO_RADIUS / max(-viewPos.z, 1.0);
            float rad = SSAO_RADIUS / (length(viewPos) + 1.0);

            occlusion = GetSpiralOcclusion(texcoord, viewPos, viewNormal, rad);
            occlusion = 1.0 - saturate(occlusion * SSAO_INTENSITY);
        #endif
    }

    #if AO_TYPE == AO_TYPE_SS
        outGIAO = vec4(vec3(0.0), occlusion);
    #endif

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #ifdef SHADOW_BLUR
            outShadow = vec4(shadowColor, shadowF);
        #endif

        #if defined SSS_ENABLED && defined SSS_BLUR
            outSSS = sssF;
        #endif
    #endif
}
