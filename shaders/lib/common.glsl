const float sunPathRotation = -30; // [-60 -50 -40 -30 -20 -15 -10 -5 0 5 10 15 20 30 40 50 60]

/*
const int colortex2Format = RGBA32UI;
const bool colortex2MipmapEnabled = false;

const int colortex4Format = RGB16F;
const bool colortex4MipmapEnabled = true;
const bool colortex4Clear = false;

const int colortex5Format = RGBA16F;
const bool colortex5MipmapEnabled = true;
const bool colortex5Clear = false;

const int colortex6Format = R16F;
const bool colortex6MipmapEnabled = false;
const bool colortex6Clear = false;

const int colortex7Format = RGB16F;
const bool colortex7MipmapEnabled = false;
const bool colortex7Clear = false;

const int colortex8Format = RGB16F;
const bool colortex8MipmapEnabled = false;
const bool colortex8Clear = false;

const int colortex9Format = R16F;
const bool colortex9MipmapEnabled = false;
const bool colortex9Clear = false;

const int colortex11Format = R16F;
const bool colortex11MipmapEnabled = false;
const bool colortex11Clear = false;
*/


// World Options
#define ENABLE_WAVING
#define HANDLIGHT_ENABLED
#define VL_ENABLED
#define BLOCKLIGHT_TEMP 3500 // [2500 2700 3000 3500 4000 5700 7000]
#define DIRECTIONAL_LIGHTMAP_STRENGTH 80 // [0 10 20 30 40 50 60 70 80 90 100]
#define SHADOW_BRIGHTNESS 0.10 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define RAIN_DARKNESS 0.2
//#define ANIM_USE_WORLDTIME


// Water Options
#define WATER_FANCY
#define WATER_REFRACTION
#define WATER_WAVE_TYPE 0 // [0 1 2]
#define WATER_SCALE 16.0
#define WATER_RADIUS 32
#define WATER_OCTAVES_NEAR 32
#define WATER_OCTAVES_FAR 16
#define WATER_OCTAVES_VERTEX 4
#define WATER_PARALLAX_DEPTH 0.02
#define WATER_PARALLAX_SAMPLES 32
#define WATER_WAVE_DEPTH 1.0
#define WATER_RESOLUTION 2048

#define WATER_WAVE_NONE 0
#define WATER_WAVE_VERTEX 1
#define WATER_WAVE_PARALLAX 2


// Atmosphere Options
#define ATMOSPHERE_TYPE 0 // [0 1]
#define ATMOSFOG_ENABLED
#define CAVEFOG_ENABLED
#define HCM_AMBIENT 0.16
#define WEATHER_OPACITY 0.4
#define G_SCATTERING_CLEAR 0.9
#define G_SCATTERING_RAIN 0.6

#define ATMOSPHERE_TYPE_FAST 0
#define ATMOSPHERE_TYPE_FANCY 1


// Shadow Options
#define SHADOW_TYPE 2 // [0 1 2 3]
#define SHADOW_FILTER 0 // [0 1 2]
#define SHADOW_PCF_SIZE 0.040 // [0.005 0.010 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.060 0.065 0.070 0.075 0.080 0.085 0.090 0.095 0.100]
#define SHADOW_PCF_SAMPLES 12 // [12 24 36]
//#define SHADOW_EXCLUDE_ENTITIES
//#define SHADOW_EXCLUDE_FOLIAGE
#define SHADOW_COLORS 0 // [0 1 2]
#define SHADOW_BIAS_SCALE 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5]
#define SHADOW_DISTORT_FACTOR 0.15 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define SHADOW_ENTITY_CASCADE 1 // [0 1 2 3]
#define SHADOW_CSM_FITRANGE
#define SHADOW_CSM_TIGHTEN
#define SHADOW_PENUMBRA_SCALE 50.0
#define SHADOW_ENABLE_HWCOMP
#define SHADOW_BASIC_BIAS 0.035
#define SHADOW_DISTORTED_BIAS 0.0016
#define SHADOW_CSM_FIT_FARSCALE 1.1
#define SHADOW_CSM_FITSCALE 0.1
#define CSM_PLAYER_ID 0


// Material Options
#define MATERIAL_FORMAT 1 // [0 1 2 3]
#define SSS_ENABLED
#define SSS_MAXDIST 2.8
#define SSS_FILTER 0 // [0 1 2]
#define SSS_PCF_SIZE 0.015 // [0.005 0.010 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.060 0.065 0.070 0.075 0.080 0.085 0.090 0.095 0.100]
#define SSS_PCF_SAMPLES 12 // [12 24 36]
#define SKYREFLECT_ENABLED
#define REFLECTION_MODE 1 // [0 1]

#define MATERIAL_FORMAT_DEFAULT 0
#define MATERIAL_FORMAT_LABPBR 1
#define MATERIAL_FORMAT_OLDPBR 2
#define MATERIAL_FORMAT_PATRIX 3

#define REFLECTION_MODE_NONE 0
#define REFLECTION_MODE_SKY 1
#define REFLECTION_MODE_SCREEN 2


// Material Parallax Options
#define PARALLAX_ENABLED
#define PARALLAX_DISTANCE 24.0
#define PARALLAX_SHADOWS_ENABLED
//#define PARALLAX_SMOOTH
//#define PARALLAX_SMOOTH_NORMALS
//#define PARALLAX_SLOPE_NORMALS
#define PARALLAX_DEPTH 0.25 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define PARALLAX_SAMPLES 32 // [16 32 64 128 256]
#define PARALLAX_SHADOW_SAMPLES 32 // [16 32 64 128 256]
#define PARALLAX_SOFTSHADOW_FACTOR 1.0
//#define PARALLAX_USE_TEXELFETCH
//#define PARALLAX_SHADOW_FIX


// Camera Options
#define CAMERA_EXPOSURE_MODE 2 // [0 1 2]
#define CAMERA_EXPOSURE 0 // [-17 -16 -15 -14 -13 -12 -11 -10 -9 -8 -7 -6 -5 -4 -3 -2 -1 0 1 2 3 4 5 6]
#define CAMERA_LUM_MIN 20.0
#define CAMERA_LUM_MAX 20000.0
#define EXPOSURE_POINT 0.2
#define EXPOSURE_SPEED_UP 0.04
#define EXPOSURE_SPEED_DOWN 0.04

#define EXPOSURE_MODE_MANUAL 0
#define EXPOSURE_MODE_EYEBRIGHTNESS 1
#define EXPOSURE_MODE_MIPMAP 2
#define EXPOSURE_MODE_HISTOGRAM 3


// Effect Options
#define RSM_ENABLED
#define RSM_INTENSITY 2 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
#define RSM_FILTER_SIZE 0.8 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0]
#define RSM_SAMPLE_COUNT 100 // [100 200 400]
#define RSM_SCALE 1 // [0 1 2]
//#define RSM_UPSCALE
#define BLOOM_ENABLED
#define BLOOM_SMOOTH
#define BLOOM_POWER 8.0
#define BLOOM_SCALE 60.0
#define BLOOM_STRENGTH 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define TONEMAP 2 // [0 1 2 3 4 5 6 7 8 9 10 11 12]
//#define AF_ENABLED
#define AF_SAMPLES 16.0


// Debug Options
#define DEBUG_VIEW 0 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
//#define DEBUG_EXPOSURE_METERS
#define IS_OPTIFINE
//#define IRIS_FEATURE_SEPARATE_HW_SAMPLERS
//#define IRIS_FEATURE_CHUNK_OFFSET

#define DEBUG_VIEW_GBUFFER_COLOR 1
#define DEBUG_VIEW_GBUFFER_NORMAL 2
#define DEBUG_VIEW_GBUFFER_SPECULAR 3
#define DEBUG_VIEW_GBUFFER_LIGHTING 4
#define DEBUG_VIEW_SHADOW_ALBEDO 5
#define DEBUG_VIEW_SHADOW_NORMAL 6
#define DEBUG_VIEW_SHADOW_SSS 7
#define DEBUG_VIEW_SHADOW_DEPTH0 8
#define DEBUG_VIEW_SHADOW_DEPTH1 9
#define DEBUG_VIEW_HDR 10
#define DEBUG_VIEW_LUMINANCE 11
#define DEBUG_VIEW_RSM 12
#define DEBUG_VIEW_BLOOM 13
#define DEBUG_VIEW_PREV_COLOR 14
#define DEBUG_VIEW_PREV_LUMINANCE 15
#define DEBUG_VIEW_WATER_WAVES 16


// INTERNAL
#define TITLE
#define IOR_AIR 1.0
#define PI 3.1415926538
#define TAU 6.2831853076
#define EPSILON 1e-7
#define GAMMA 2.2

#define BUFFER_DEFERRED colortex2
#define BUFFER_HDR colortex4
#define BUFFER_HDR_PREVIOUS colortex5
#define BUFFER_LUMINANCE colortex6
#define BUFFER_BLOOM colortex7
#define BUFFER_RSM_COLOR colortex8
#define BUFFER_RSM_DEPTH colortex9
#define BUFFER_BRDF_LUT colortex10
#define BUFFER_WATER_WAVES colortex11

const float sunLumen = 240000.0;//16000000;
const float moonLumen = 2500.0;
const float StarLumen = 2000.0;
//const float BlockLightLumen = 2000;
const float EmissionLumens = 100000.0;

const float SunLux = 64000.0;
const float SunOvercastLux = 24000;
const float MoonLux = 30.0;
const float MoonOvercastLux = 2.0;
const float BlockLightLux = 9000;
const float MinWorldLux = 2.0;

const float DaySkyLumen = 6000.0;
const float NightSkyLumen = 1200.0;

const vec3 minLight = vec3(0.01);
const float tile_dist_bias_factor = 0.012288;
const vec3 handOffset = vec3(0.2, -0.3, -0.2);
const vec3 luma_factor = vec3(0.2126f, 0.7152f, 0.0722f);
const float invPI = 1.0 / PI;


#if MC_VERSION < 11700 || !defined IS_OPTIFINE
    const float alphaTestRef = 0.1;
#endif

// #ifdef WORLD_NETHER
//     #undef SHADOW_ENABLED
// #endif

#if SHADOW_TYPE != 1 && SHADOW_TYPE != 2
	#undef SHADOW_DISTORT_FACTOR
#endif

// #if SHADOW_TYPE != 3
// 	#undef DEBUG_CASCADE_TINT
// 	#undef SHADOW_CSM_FITRANGE
// 	#undef SHADOW_CSM_TIGHTEN
// #endif

// #if defined IS_OPTIFINE && SHADOW_TYPE == 3 && defined SHADOW_CSM_TIGHTEN && !defined SHADOW_EXCLUDE_ENTITIES
// 	#define SHADOW_EXCLUDE_ENTITIES
// #endif

// #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
//     #undef PARALLAX_ENABLED
// #endif

#ifdef PARALLAX_ENABLED
    #ifdef PARALLAX_SMOOTH
        #undef PARALLAX_SLOPE_NORMALS
    #else
        #undef PARALLAX_SMOOTH_NORMALS
    #endif
#else
    #undef PARALLAX_SMOOTH
    #undef PARALLAX_SMOOTH_NORMALS
    #undef PARALLAX_SLOPE_NORMALS
    #undef PARALLAX_SHADOWS_ENABLED
#endif

#if !defined SHADOW_ENABLED || SHADOW_TYPE == 0
    #undef RSM_ENABLED
    #undef SSS_ENABLED
    #undef VL_ENABLED
#endif

#if SHADOW_TYPE == 3
    // VL is not currently supported with CSM
    #undef VL_ENABLED
#endif

#if !defined RSM_ENABLED || RSM_SCALE == 0
    #undef RSM_UPSCALE
#endif

#ifdef TITLE
#endif
#ifdef CAVEFOG_ENABLED
#endif
#ifdef SHADOW_EXCLUDE_ENTITIES
#endif
#ifdef SHADOW_EXCLUDE_FOLIAGE
#endif
#ifdef RSM_ENABLED
#endif
#ifdef RSM_SCALE
#endif
#ifdef RSM_UPSCALE
#endif


// float pow2(const in float x) {
//     return x * x;
// }

// float pow3(const in float x) {
//     return x * x * x;
// }

#define pow2(x) (x*x)
#define pow3(x) (x*x*x)
#define pow4(x) (x*x*x*x)
#define pow5(x) (x*x*x*x*x)
#define saturate(x) clamp(x, 0.0, 1.0)
#define rcp(x) (1.0 / (x))

float RGBToLinear(const in float color) {
    return pow(color, GAMMA);
}

vec3 RGBToLinear(const in vec3 color) {
	return pow(color, vec3(GAMMA));
}

vec3 LinearToRGB(const in vec3 color) {
	return pow(color, vec3(1.0 / GAMMA));
}

float luminance(const in vec3 color) {
   return dot(color, luma_factor);
}

float expStep(float x)
{
    return 1.0 - exp(-x*x);
}

float f0ToIOR(const in float f0) {
    float sqrt_f0 = sqrt(f0);
    return (1.0f + sqrt_f0) / max(1.0f - sqrt_f0, EPSILON);
}

vec3 f0ToIOR(const in vec3 f0) {
    vec3 sqrt_f0 = sqrt(f0);
    return (1.0f + sqrt_f0) / max(1.0f - sqrt_f0, vec3(EPSILON));
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
