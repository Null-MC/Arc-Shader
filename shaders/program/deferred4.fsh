#define RENDER_FRAG
#define RENDER_DEFERRED
#define RENDER_AO

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: 10 */
layout(location = 0) out float outColor0;


#define MOD3 vec3(0.1031, 0.11369, 0.13787)

float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * MOD3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

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
    float occlusion = 1.0;

    if (clipDepth < 1.0) {
        vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;
        vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

        uint deferredNormal = texelFetch(BUFFER_DEFERRED, itexFull, 0).g;
        vec3 viewNormal = unpackUnorm4x8(deferredNormal).xyz;
        viewNormal = normalize(viewNormal * 2.0 - 1.0);
        
        //float rad = SSAO_RADIUS / max(-viewPos.z, 1.0);
        float rad = SSAO_RADIUS / (length(viewPos) + 1.0);

        occlusion = GetSpiralOcclusion(texcoord, viewPos, viewNormal, rad);
        occlusion = max(1.0 - occlusion * SSAO_INTENSITY, 0.0);
    }

    outColor0 = saturate(occlusion);
}
