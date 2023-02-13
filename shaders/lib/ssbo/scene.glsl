#ifdef RENDER_BEGIN
    layout(std430, binding = 0) buffer sceneData
#else
    layout(std430, binding = 0) readonly buffer sceneData
#endif
{
    float sceneExposure;            // 4
    mat4 shadowModelViewEx;         // 64
    mat4 shadowProjectionEx;        // 64

    vec2 skyLightLevels;            // 8
    vec3 skySunColor;               // 16
    vec3 sunTransmittanceEye;       // 16
    vec3 skyMoonColor;              // 16
    vec3 moonTransmittanceEye;      // 16
    //float skyMoonPhaseLevel,
    vec3 blockLightColor;           // 16

    // CSM
    float cascadeSize[4];           // 16
    vec2 shadowProjectionSize[4];   // 32
    vec2 shadowProjectionPos[4];    // 32
    mat4 cascadeProjection[4];      // 256
    vec2 cascadeViewMin[4];         // 32
    vec2 cascadeViewMax[4];         // 32
};
