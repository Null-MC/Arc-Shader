const float shadowDistance = 150; // [50 100 150 200 300 400 800]
const int shadowMapResolution = 2048; // [128 256 512 1024 2048 4096 8192]

#ifdef MC_SHADOW_QUALITY
    const float shadowMapSize = shadowMapResolution * MC_SHADOW_QUALITY;
#else
    const float shadowMapSize = shadowMapResolution;
#endif

const float shadowPixelSize = 1.0 / shadowMapSize;

//const bool shadowcolor0Nearest = false;


// FOR HW FILTERING ONLY
const bool generateShadowMipmap = false;
const bool shadowHardwareFiltering0 = true;
const bool shadowtex0Mipmap = false;
const bool shadowtex0Nearest = false;
const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = true;
