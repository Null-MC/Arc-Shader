#define WORLD_OVERWORLD
#define SHADOW_ENABLED
//#define WIND_ENABLED
#define SKY_ENABLED

const float shadowDistance = 100; // [0 50 100 150 200 300 400 800]
const int shadowMapResolution = 2048; // [512 1024 2048 4096 8192]
const float shadowDistanceRenderMul = 1.0;

#ifdef MC_SHADOW_QUALITY
    const float shadowMapSize = shadowMapResolution * MC_SHADOW_QUALITY;
#else
    const float shadowMapSize = shadowMapResolution;
#endif

const float shadowPixelSize = 1.0 / shadowMapSize;
