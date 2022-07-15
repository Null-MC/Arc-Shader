const float shadowDistance = 150; // [50 100 150 200 300 400 800]
const int shadowMapResolution = 2048; // [128 256 512 1024 2048 4096 8192]

#ifdef MC_SHADOW_QUALITY
    const float shadowMapSize = shadowMapResolution * MC_SHADOW_QUALITY;
#else
    const float shadowMapSize = shadowMapResolution;
#endif

const float shadowPixelSize = 1.0 / shadowMapSize;

const bool shadowcolor0Nearest = true;

const bool generateShadowMipmap = true;
const bool shadowtex0Mipmap = false;
const bool shadowtex0Nearest = true;
const bool shadowHardwareFiltering0 = false;
const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;
const bool shadowHardwareFiltering1 = true;

const vec4 shadowcolor0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
//const vec4 shadowcolor1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

const float ambientOcclusionLevel = 0.5f;

#define SHADOW_ENABLED
#define SKY_ENABLED
