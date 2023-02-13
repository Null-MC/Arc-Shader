#ifdef RENDER_SETUP
    layout(std430, binding = 1) buffer vogelDiskData
#else
    layout(std430, binding = 1) readonly buffer vogelDiskData
#endif
{
    vec2 pcfDiskOffset[32];     // 256
    vec2 pcssDiskOffset[32];    // 256
    vec3 sssDiskOffset[32];     // 512
    vec2 ssaoDiskOffset[32];    // 256
};
