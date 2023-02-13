//#define RENDER_SETUP_DISKS
#define RENDER_SETUP
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/ssbo/vogel_disk.glsl"
#endif


//const float goldenAngle = PI * (3.0 - sqrt(5.0));
const float PHI = (1.0 + sqrt(5.0)) / 2.0;

vec3 GetVogelSample(const in int index, const in float sampleCountF) {
    float theta = index * GOLDEN_ANGLE + PHI;
    float r = sqrt((index + 0.5) * sampleCountF);
    return vec3(cos(theta), sin(theta), r);
}

vec2 GetVogelDiskSample(const in int index, const in float sampleCountF) {
    vec3 vogelSample = GetVogelSample(index, sampleCountF);
    return vogelSample.xy * vogelSample.z;
}

void main() {
    #ifdef IRIS_FEATURE_SSBO
        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            const float pcfSampleCountF = rcp(SHADOW_PCF_SAMPLES);
            for (int i = 0; i < SHADOW_PCF_SAMPLES; i++)
                pcfDiskOffset[i] = GetVogelDiskSample(i, pcfSampleCountF);

            const float pcssSampleCountF = rcp(SHADOW_PCSS_SAMPLES);
            for (int i = 0; i < SHADOW_PCSS_SAMPLES; i++)
                pcssDiskOffset[i] = GetVogelDiskSample(i, pcssSampleCountF);

            const float sssSampleCountF = rcp(SSS_PCF_SAMPLES);
            for (int i = 0; i < SSS_PCF_SAMPLES; i++)
                sssDiskOffset[i] = GetVogelSample(i, sssSampleCountF);
        #endif

        const float ssaoSampleCountF = rcp(SSAO_SAMPLES);
        for (int i = 0; i < SSAO_SAMPLES; i++)
            ssaoDiskOffset[i] = GetVogelSample(i, ssaoSampleCountF).xy;
    #endif

    barrier();
}
