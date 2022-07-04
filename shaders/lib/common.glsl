const float sunPathRotation = -30; // [-60 -50 -40 -30 -20 -15 -10 -5 0 5 10 15 20 30 40 50 60]
const bool colortex8Clear = false;

/*
const int colortex4Format = RGB16F;
*/


// World Options
#define ENABLE_WAVING
#define HANDLIGHT_ENABLED
#define SHADOW_BRIGHTNESS 0.10 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
//#define ANIM_USE_WORLDTIME


// Atmosphere Options
//#define ATMOSPHERE_ENABLED
#define HCM_AMBIENT 0.16


// Material Options
#define SSS_ENABLED
#define SSS_MAXDIST 2.8
#define SSS_FILTER 0 // [0 1 2]
#define SSS_PCF_SIZE 0.015 // [0.005 0.010 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.060 0.065 0.070 0.075 0.080 0.085 0.090 0.095 0.100]
#define SSS_PCF_SAMPLES 12 // [12 24 36]


// Material Parallax Options
#define PARALLAX_ENABLED
#define PARALLAX_DISTANCE 40.0
#define PARALLAX_SHADOWS_ENABLED
//#define PARALLAX_SLOPE_NORMALS
//#define PARALLAX_SMOOTH
#define PARALLAX_DEPTH 0.25 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define PARALLAX_SAMPLES 32 // [16 32 64 128 256]
#define PARALLAX_SHADOW_SAMPLES 32 // [16 32 64 128 256]
#define PARALLAX_SOFTSHADOW_FACTOR 1.0
//#define PARALLAX_USE_TEXELFETCH
//#define PARALLAX_SHADOW_FIX


// Shadow Options
#define SHADOW_ENABLED
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


// Effect Options
//#define SSR_ENABLED
#define RSM_ENABLED
#define RSM_INTENSITY 8 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
#define RSM_FILTER_SIZE 0.8 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define RSM_SCALE 1 // [0 1 2]
//#define RSM_UPSCALE
#define TONEMAP 2 // [0 1 2 3 4 5 6 7 8 9 10 11 12]
#define CAMERA_EXPOSURE 0 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
//#define AF_ENABLED
#define AF_SAMPLES 16.0


// Debug Options
#define DEBUG_SHADOW_BUFFER 0 // [0 1 2 3 4 5 6]
#define IS_OPTIFINE

#define DEBUG_VIEW_SHADOW_ALBEDO 1
#define DEBUG_VIEW_SHADOW_NORMAL 2
#define DEBUG_VIEW_SHADOW_SSS 3
#define DEBUG_VIEW_SHADOW_DEPTH0 4
#define DEBUG_VIEW_SHADOW_DEPTH1 5
#define DEBUG_VIEW_RSM 6


// INTERNAL
#define IOR_AIR 1.0
#define PI 3.1415926538
#define EPSILON 1e-6
#define GAMMA 2.2

const vec3 minLight = vec3(0.01);
const float tile_dist_bias_factor = 0.012288;
const vec3 handOffset = vec3(0.2, -0.3, -0.2);
const vec3 luma_factor = vec3(0.2126f, 0.7152f, 0.0722f);
const float invPI = 1.0 / PI;


#if MC_VERSION < 11700 || !defined IS_OPTIFINE
    const float alphaTestRef = 0.1;
    //const vec3 chunkOffset = vec3(0.0);
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

#ifndef PARALLAX_ENABLED
    #undef PARALLAX_SMOOTH
    #undef PARALLAX_SLOPE_NORMALS
    #undef PARALLAX_SHADOWS_ENABLED
#endif

#ifdef PARALLAX_SMOOTH
    #undef PARALLAX_SLOPE_NORMALS
#endif

#if !defined SHADOW_ENABLED || SHADOW_TYPE == 0
    #undef RSM_ENABLED
    #undef SSS_ENABLED
#endif

#if !defined RSM_ENABLED || RSM_SCALE == 0
    #undef RSM_UPSCALE
#endif

#ifdef ATMOSPHERE_ENABLED
#endif
#ifdef SHADOW_EXCLUDE_ENTITIES
#endif
#ifdef SHADOW_EXCLUDE_FOLIAGE
#endif
#ifdef RSM_ENABLED
#endif
#ifdef RSM_UPSCALE
#endif


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

vec3 RestoreNormalZ(const in vec2 normalXY) {
    vec3 normal;
    normal.xy = normalXY * 2.0 - 1.0;
    normal.z = sqrt(max(1.0 - dot(normal.xy, normal.xy), EPSILON));
    return normal;
}
