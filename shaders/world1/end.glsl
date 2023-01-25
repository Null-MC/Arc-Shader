#define WORLD_END
#define SHADOW_ENABLED
#define SKY_ENABLED
#define WORLD_WATER_ENABLED
//#define WIND_ENABLED

#define SKY_FANCY_LUM 16000.0
#define FOG_AREA_LUMINANCE 200.0

const float SunLux = 800.0;

const float sunLumen = 1.6e9;
const float StarLumen = 200.0;

const float shadowDistance = 100; // [0 25 50 75 100 150 200 250 300 400 600 800]
const int shadowMapResolution = 2048; // [512 1024 2048 3072 4096 6144 8192]
const float shadowDistanceRenderMul = 1.0;
const float MinWorldLux = 22.0;

#ifdef MC_SHADOW_QUALITY
    const float shadowMapSize = shadowMapResolution * MC_SHADOW_QUALITY;
#else
    const float shadowMapSize = shadowMapResolution;
#endif

const float shadowPixelSize = 1.0 / shadowMapSize;
