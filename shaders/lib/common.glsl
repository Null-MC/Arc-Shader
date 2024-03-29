const float sunPathRotation = -30; // [-60 -50 -40 -30 -20 -15 -10 -5 0 5 10 15 20 30 40 50 60]

/*
const int colortex0Format = RGBA32UI;
const int colortex1Format = R16F;
const int colortex2Format = RGBA16F;
const int colortex3Format = R16F;
const int colortex4Format = RGB16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = R32F;
const int colortex7Format = RGB16F;
const int colortex9Format = RGBA16F;
const int colortex10Format = RGBA16F;
const int colortex11Format = RGB16F;
*/

const bool noisetexMipmapEnabled = true;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex0MipmapEnabled = false;
const bool colortex0Clear = true;

const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const bool colortex1MipmapEnabled = false;
const bool colortex1Clear = true;

const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex2MipmapEnabled = false;
const bool colortex2Clear = true;

const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const bool colortex3MipmapEnabled = false;
const bool colortex3Clear = true;

const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const bool colortex4MipmapEnabled = false;
const bool colortex4Clear = true;

const bool colortex5MipmapEnabled = true;
const bool colortex5Clear = false;

const bool colortex6MipmapEnabled = false;
const bool colortex6Clear = false;

const bool colortex7MipmapEnabled = false;
const bool colortex7Clear = false;

const bool colortex10MipmapEnabled = false;
const bool colortex10Clear = false;

const bool colortex11MipmapEnabled = false;
const bool colortex11Clear = false;


//#define IS_IRIS
#define PHYSICS_OCEAN_SUPPORT


// World Options
#define WAVING_MODE 2 // [0 1 2]
#define HANDLIGHT_ENABLED
#define BLOCK_OUTLINE 3 // [0 1 2 3]
#define BLOCKLIGHT_TEMP 2700 // [2500 2700 3000 3500 4000 5700 7000]
#define DIRECTIONAL_LIGHTMAP_STRENGTH 70 // [0 10 20 30 40 50 60 70 80 90 100]
//#define ANIM_USE_WORLDTIME
#define WETNESS_MODE 2 // [0 1 2]
#define SNOW_MODE 2 // [0 1 2]
#define EMISSIVE_POWER 2.2 // [1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
#define LAVA_TYPE 1 // [0 1]


// Water Options
#define WATER_FOAM_ENABLED
#define WATER_WAVE_ENABLED
//#define WATER_REFRACTION_FANCY
#define REFRACTION_STRENGTH 100 // [0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 85 100 110 120 130 140 150 160 170 180 190 200]
//#define WATER_POROSITY_DARKEN
#define WATER_CAMERA_BLUR 1 // [0 1 2]
#define WATER_SCALE 10.0
#define WATER_RADIUS 50
#define WATER_OCTAVES_NEAR 26 // [16 18 20 22 24 26 28 30 32 34 36 38]
#define WATER_OCTAVES_FAR 12
#define WATER_OCTAVES_VERTEX 8
#define WATER_OCTAVES_DIST 120.0
#define WATER_WAVE_DEPTH 100 // [25 50 100 150 200 250 300]
#define WATER_NORMAL_STRENGTH 0.1
#define WATER_VL_ENABLED
#define WATER_VL_SAMPLES 6 // [4 6 8 12 16 24]
#define WATER_VL_NOISE
//#define WATER_CAUSTICS


// Material Options
#define MATERIAL_FORMAT 0 // [0 1 2 3]
#define REFLECTION_MODE 2 // [0 1 2]
#define MATERIAL_WET_DARKEN 80 // [0 10 20 30 40 50 60 70 80 90 100 11 120 130 140 150 160 170 180 190 200]
//#define MATERIAL_SMOOTH_NORMALS
#define PARTICLE_PBR
#define SSS_ENABLED
#define SSS_STRENGTH 120 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define SSS_MAXDIST 6 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
#define SSS_PCF_SIZE 0.2 // [0.02 0.04 0.06 0.08 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.6 0.8 1.0 1.5 2.0 2.5 3.0]
#define SSS_PCF_SAMPLES 4 // [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]
//#define SSS_NORMALIZE_ALBEDO
#define SSS_BLUR
#define SSR_QUALITY 1 // [2 1 0]
#define SSR_IGNORE_HAND
#define SSR_HIZ


// Sky Options
#define SKY_CLOUD_LEVEL 180 // [-1 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220 230 240 250 260 270 280]
#define WEATHER_OPACITY 100 // [5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define SUN_TEMP 5000.0 // [3500 4000 4500 5000 5500 6000 6500 7000]
#define MOON_TEMP 4000.0
#define SKY_SUN_TYPE 1 // [0 1]


// Atmosphere Options
//#define LIGHTLEAK_FIX
#define SKY_VL_ENABLED
#define SKY_VL_SAMPLES 12 // [8 12 16 20 24 32]
//#define SKY_VL_NOISE
#define SMOKE_ENABLED
#define VL_SMOKE_DENSITY 40 // [0 10 20 30 40 50 60 70 80 90 100]


// Shadow Options
#define SHADOW_TYPE 2 // [0 2 3]
#define SHADOW_FILTER 1 // [0 1 2]
#define SHADOW_PCF_SIZE 8 // [1 2 3 4 5 6 7 8 9 10 12 14 16 18 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define SHADOW_PCF_SAMPLES 4 // [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]
#define SHADOW_PCSS_SAMPLES 4 // [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]
//#define SHADOW_EXCLUDE_ENTITIES
//#define SHADOW_EXCLUDE_FOLIAGE
//#define SHADOW_COLOR
#define SHADOW_PARTICLES
#define SHADOW_BIAS_SCALE 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220 230 240 250]
#define SHADOW_DISTORT_FACTOR 0.25 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define SHADOW_ENTITY_CASCADE 1 // [0 1 2 3]
#define SHADOW_PENUMBRA_SCALE 0.1
#define SHADOW_BASIC_BIAS 0.035
//#define SHADOW_DISTORTED_BIAS 0.0016
//#define SHADOW_CONTACT 0 // [0 1 2]
#define SHADOW_CSM_FIT_FARSCALE 1.1
#define SHADOW_CSM_FITSCALE 0.1
#define SHADOW_NORMAL_BIAS 0.012
#define CSM_PLAYER_ID 0
#define SHADOW_CLOUD
#define SHADOW_BLUR


// Material Parallax Options
#define PARALLAX_ENABLED
#define PARALLAX_SHAPE 0 // [0 1 2]
#define PARALLAX_DISTANCE 24.0
#define PARALLAX_SHADOWS_ENABLED
#define PARALLAX_DEPTH 0.25 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define PARALLAX_SAMPLES 32 // [16 32 64 128 256]
#define PARALLAX_SHADOW_SAMPLES 32 // [16 32 64 128 256]
#define PARALLAX_SOFTSHADOW_FACTOR 1.0
//#define PARALLAX_USE_TEXELFETCH
//#define PARALLAX_SHADOW_FIX
//#define PARALLAX_DEPTH_WRITE


// Camera Options
#define CAMERA_EXPOSURE_MODE 2 // [0 1 2]
#define CAMERA_EXPOSURE 0.0 // [-17 -16 -15 -14 -13 -12 -11 -10 -9.0 -8.0 -7.0 -6.0 -5.0 -4.0 -3.0 -2.0 -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0 6.0]
#define CAMERA_LUM_MIN 40.0
#define CAMERA_LUM_MAX 8000.0
//#define EXPOSURE_POINT 0.2
#define EXPOSURE_SPEED_UP 0.5
#define EXPOSURE_SPEED_DOWN 0.3
#define TONEMAP 8 // [0 1 2 3 4 5 6 7 8 9 10 11 12]

#define CAMERA_BRIGHTNESS 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define CAMERA_SATURATION 100 // [0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]


// Effect Options
//#define BLOOM_ENABLED
#define BLOOM_SMOOTH
//#define BLOOM_SCALE 60.0
#define BLOOM_THRESHOLD 0.02 // [0.01 0.02 0.03 0.04 0.05 0.06 0.08 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.35 0.40 0.45 0.50]
#define BLOOM_THRESHOLD_WATER 0.12
#define BLOOM_THRESHOLD_NIGHTVISION 0.06
#define BLOOM_POWER 1.8 // [1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0]
#define BLOOM_POWER_WATER 1.6
#define BLOOM_POWER_NIGHTVISION 1.2
#define BLOOM_STRENGTH 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define BLOOM_LOD_MAX 0 // [0 1 2 3 4 5 6 7 8 9]
#define VL_DITHER
#define VL_PARTICLES
#define AO_TYPE 2 // [0 1 2]
#define SSAO_SAMPLES 12 // [2 4 6 8 10 12 14 16 24 32]
#define SSAO_INTENSITY 4 // [5 10 15 20 25 30 35 40 45 50 60 70 80 90 100]
#define SSAO_SCALE 0.1
#define SSAO_BIAS 0.02
#define SSAO_RADIUS 3.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0]
#define SSAO_MAX_DIST 1.0
//#define SSAO_UPSCALE
#define SSGI_ENABLED
#define SSGI_STRENGTH 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]

//#define DOF_ENABLED
#define DOF_SCALE 2.0 // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
// Smaller = nicer blur, larger = faster
#define DOF_STEP_SIZE 0.5 // [0.5 1.0 1.5 2.0]
#define DOF_MAX_SIZE 10.0 // [5.0 10.0 15.0 20.0 25.0 30.0]


// Colored Lighting
//#define LIGHT_COLOR_ENABLED
#define LIGHT_FLICKER_ENABLED
#define LIGHT_COLOR_NORMAL_CHECK
#define LIGHT_COLOR_PBR
//#define LIGHT_LAVA_ENABLED
#define LIGHT_REDSTONE_ENABLED
#define LIGHT_BIN_MAX_COUNT 24 // [4 8 12 16 20 24 32 36 40 44 48 52 56 60 64 68 72 76 80 84 88 92 96 100 110 120 130 140 150]
#define LIGHT_BIN_SIZE 8 // [4 8 16]
#define LIGHT_SIZE_XZ 16 // [4 8 16 32 64]
#define LIGHT_SIZE_Y 8 // [4 8 16 32]
#define LIGHT_FALLBACK


// Debug Options
#define DEBUG_VIEW 0 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]
//#define DEBUG_EXPOSURE_METERS
#define DITHER_FINAL
//#define VANILLA_NOISE_ENABLED
#define PARTICLE_OPACITY 0.8
#define PARTICLE_RESOLUTION 8 // [8 16 32 64 128]
//#define PARTICLE_ROUNDING
#define HCM_LAZANYI
#define METAL_AMBIENT 0.4
//#define SHADOW_CONTACT_DITHER
//#define SKY_DITHER
//#define AF_ENABLED
#define AF_SAMPLES 16.0
#define AA_TYPE 1 // [0 1]

#if SSR_QUALITY == 0
    #define SSR_SCALE 1
    #define SSR_MAXSTEPS 512
#elif SSR_QUALITY == 1
    #define SSR_SCALE 2
    #define SSR_MAXSTEPS 256
#elif SSR_QUALITY == 2
    #define SSR_SCALE 4
    #define SSR_MAXSTEPS 128
#endif


// INTERNAL
#define TITLE
#define SEA_LEVEL 62
#define ATMOSPHERE_LEVEL 2400
#define WATER_SMOOTH 1.0
#define IOR_AIR 1.000293
#define IOR_WATER 1.333
#define PI 3.1415926538
#define TAU 6.2831853076
#define GOLDEN_ANGLE 2.39996323
#define EPSILON 1e-7
#define GAMMA 2.2

#define attribute in

const float EmissionLumens = 20000;

const float BlockLightLux = 2400.0;
// const float MinWorldLux = 8.0;

const vec3 CLOUD_COLOR = vec3(0.248, 0.225, 0.273);
const vec3 SNOW_COLOR = vec3(0.590, 0.665, 0.682);
const vec3 POWDER_SNOW_COLOR = vec3(0.820, 0.868, 0.879);

const vec3 handOffsetMain = vec3(0.6, -0.3, -0.2);
const vec3 handOffsetAlt = vec3(-0.6, -0.3, -0.2);

const vec3 luma_factor = vec3(0.2126, 0.7152, 0.0722);
const vec2 EPSILON2 = vec2(EPSILON);
const vec3 EPSILON3 = vec3(EPSILON);
const float invPI = 1.0 / PI;

const float wetnessHalflife = 300.0;
const float drynessHalflife = 10.0;

#if MC_VERSION < 11700
    const float alphaTestRef = 0.1;
#endif

const float WeatherOpacityF = WEATHER_OPACITY * 0.01;
const float DirectionalLightmapStrengthF = DIRECTIONAL_LIGHTMAP_STRENGTH * 0.01;
const float RefractionStrengthF = REFRACTION_STRENGTH * 0.01;
const float WaterWaveDepthF = WATER_WAVE_DEPTH * 0.01;
const float shadowPcfSize = SHADOW_PCF_SIZE * 0.01;
const float SmokeDensityF = VL_SMOKE_DENSITY * 0.01;
const float MaterialWetDarkenF = MATERIAL_WET_DARKEN * 0.01;
const float SSGIStrengthF = SSGI_STRENGTH * 0.01;

const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 2.0f;
const float shadowDistance = 100; // [0 25 50 75 100 150 200 250 300 400 600 800]
const int shadowMapResolution = 2048; // [512 1024 2048 3072 4096 6144 8192]

#ifdef MC_SHADOW_QUALITY
    const float shadowMapSize = shadowMapResolution * MC_SHADOW_QUALITY;
#else
    const float shadowMapSize = shadowMapResolution;
#endif

const float shadowPixelSize = 1.0 / shadowMapSize;


#ifdef IS_IRIS
#endif
#ifdef REFLECTION_MODE
#endif
#ifdef WATER_WAVE_ENABLED
#endif
#ifdef SMOKE_ENABLED
#endif
#ifdef PARALLAX_ENABLED
#endif
#ifdef PARALLAX_SHADOWS_ENABLED
#endif
#ifdef PARALLAX_DEPTH_WRITE
#endif
#ifdef SHADOW_TYPE
#endif
#ifdef SHADOW_EXCLUDE_ENTITIES
#endif
#ifdef SHADOW_EXCLUDE_FOLIAGE
#endif
#ifdef SHADOW_PARTICLES
#endif
#ifdef RSM_ENABLED
#endif
#ifdef RSM_SCALE
#endif
#ifdef RSM_UPSCALE
#endif
#ifdef VL_PARTICLES
#endif
#ifdef VL_DITHER
#endif
#ifdef SSS_NORMALIZE_ALBEDO
#endif
#ifdef SSS_BLUR
#endif
#ifdef DOF_ENABLED
#endif
#ifdef SKY_VL_NOISE
#endif
#ifdef SHADOW_BLUR
#endif
#ifdef LIGHT_COLOR_ENABLED
#endif

#ifdef PHYSICS_OCEAN
#endif



#define pow2(x) (x*x)
#define pow3(x) (x*x*x)
#define pow4(x) (x*x*x*x)
#define pow5(x) (x*x*x*x*x)
#define rcp(x) (1.0 / (x))

float saturate(const in float x) {return clamp(x, 0.0, 1.0);}
vec2 saturate(const in vec2 x) {return clamp(x, vec2(0.0), vec2(1.0));}
vec3 saturate(const in vec3 x) {return clamp(x, vec3(0.0), vec3(1.0));}

float minOf(vec2 vec) {return min(vec[0], vec[1]);}
float minOf(vec3 vec) {return min(min(vec[0], vec[1]), vec[2]);}
float minOf(vec4 vec) {return min(min(vec[0], vec[1]), min(vec[2], vec[3]));}

float maxOf(vec2 vec) {return max(vec[0], vec[1]);}
float maxOf(vec3 vec) {return max(max(vec[0], vec[1]), vec[2]);}

vec3 unproject(const in vec4 pos) {
    return pos.xyz / pos.w;
}

float RGBToLinear(const in float x) {
    //return pow(color, GAMMA);
    float linearLo = x / 12.92;
    float linearHi = pow((x + 0.055) / 1.055, 2.4);
    return mix(linearLo, linearHi, step(x, 0.04045));
}

vec3 RGBToLinear(const in vec3 x) {
	//return pow(color, vec3(GAMMA));
    vec3 linearLo = x / 12.92;
    vec3 linearHi = pow((x + 0.055) / 1.055, vec3(2.4));
    return mix(linearHi, linearLo, step(x, vec3(0.04045)));
}

vec3 LinearToRGB(const in vec3 x) {
	//return pow(color, vec3(1.0 / GAMMA));
    vec3 sRGBLo = x * 12.92;
    vec3 sRGBHi = pow(abs(x), vec3(1.0 / 2.4)) * 1.055 - 0.055;
    return mix(sRGBHi, sRGBLo, step(x, vec3(0.0031308)));
}

float luminance(const in vec3 color) {
   return dot(color, luma_factor);
}

void setLuminance(inout vec3 color, const in float targetLuminance) {
    color *= (targetLuminance / luminance(color));
}

float expStep(float x) {
    return 1.0 - exp(-x*x);
}

float f0ToIOR(const in float f0) {
    float sqrt_f0 = sqrt(max(f0, 0.02));
    return (1.0f + sqrt_f0) / max(1.0f - sqrt_f0, EPSILON);
}

vec3 f0ToIOR(const in vec3 f0) {
    vec3 sqrt_f0 = sqrt(max(f0, vec3(0.02)));
    return (1.0f + sqrt_f0) / max(1.0f - sqrt_f0, EPSILON3);
}

vec3 IORToF0(const in vec3 ior) {
    return pow((ior - 1.0) / (ior + 1.0), vec3(2.0));
}

vec3 RestoreNormalZ(const in vec2 normalXY) {
    vec3 normal;
    normal.xy = normalXY * 2.0 - 1.0;
    normal.z = sqrt(max(1.0 - dot(normal.xy, normal.xy), EPSILON));
    return normal;
}
