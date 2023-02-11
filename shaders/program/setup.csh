//#define RENDER_SETUP_DISKS
#define RENDER_SETUP
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#if defined IRIS_FEATURE_SSBO && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
    layout(std430, binding = 1) buffer shadowDiskData {
        vec2 pcfDiskOffset[32];     // 256
        vec2 pcssDiskOffset[32];    // 256
        vec3 sssDiskOffset[32];     // 512
    };
#endif


const float goldenAngle = PI * (3.0 - sqrt(5.0));
const float PHI = (1.0 + sqrt(5.0)) / 2.0;

vec2 GetVogelDiskSamplePos(const in int index, const in float sampleCountF) {
    float theta = index * goldenAngle + PHI;
    float r = sqrt((index + 0.5) * sampleCountF);
    return vec2(cos(theta), sin(theta)) * r;
}

vec3 GetVogelDiskSamplePos_SSS(const in int index, const in float sampleCountF) {
    float theta = index * goldenAngle + PHI;
    float r = sqrt((index + 0.5) * sampleCountF);
    return vec3(cos(theta), sin(theta), 1.0) * r;
}

void main() {
    #if defined IRIS_FEATURE_SSBO && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        const float pcfSampleCountF = rcp(SHADOW_PCF_SAMPLES);
        for (int i = 0; i < SHADOW_PCF_SAMPLES; i++)
            pcfDiskOffset[i] = GetVogelDiskSamplePos(i, pcfSampleCountF);

        const float pcssSampleCountF = rcp(SHADOW_PCSS_SAMPLES);
        for (int i = 0; i < SHADOW_PCSS_SAMPLES; i++)
            pcssDiskOffset[i] = GetVogelDiskSamplePos(i, pcssSampleCountF);

        const float sssSampleCountF = rcp(SSS_PCF_SAMPLES);
        for (int i = 0; i < SSS_PCF_SAMPLES; i++)
            sssDiskOffset[i] = GetVogelDiskSamplePos_SSS(i, sssSampleCountF);
    #endif

    barrier();
}
