const float sunPathRotation = -30; // [-60 -50 -40 -30 -20 -15 -10 -5 0 5 10 15 20 30 40 50 60]

/*
const int colortex2Format = RGBA32UI;
const int colortex3Format = R16F;
const int colortex4Format = R11F_G11F_B10F;
const int colortex5Format = RGBA16F;
const int colortex6Format = R16F;
const int colortex7Format = R11F_G11F_B10F;
const int colortex8Format = RGB16F;
const int colortex9Format = R32F;
const int colortex11Format = R16F;
const int colortex12Format = R32F;
*/

const bool colortex2MipmapEnabled = false;

const bool colortex3MipmapEnabled = false;
const bool colortex3Clear = false;

const bool colortex4MipmapEnabled = true;
const bool colortex4Clear = false;

const bool colortex5MipmapEnabled = true;
const bool colortex5Clear = false;

const bool colortex6MipmapEnabled = true;
const bool colortex6Clear = false;

const bool colortex7MipmapEnabled = false;
const bool colortex7Clear = false;

const bool colortex8MipmapEnabled = false;
const bool colortex8Clear = false;

const bool colortex9MipmapEnabled = false;
const bool colortex9Clear = false;

const bool colortex11MipmapEnabled = false;
const bool colortex11Clear = false;

const vec4 colortex12ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
const bool colortex12MipmapEnabled = false;
const bool colortex12Clear = false;


#define SHADER_PLATFORM 0 // [0 1]


// World Options
#define ENABLE_WAVING
#define HANDLIGHT_ENABLED
#define BLOCK_OUTLINE 3 // [0 1 2 3]
#define BLOCKLIGHT_TEMP 2700 // [2500 2700 3000 3500 4000 5700 7000]
#define DIRECTIONAL_LIGHTMAP_STRENGTH 0 // [0 10 20 30 40 50 60 70 80 90 100]
#define SHADOW_BRIGHTNESS 0.10 // [0.00 0.02 0.04 0.06 0.08 0.10 0.12 0.14 0.16 0.32 0.48 0.64 1.00]
#define RAIN_DARKNESS 0.2
//#define ANIM_USE_WORLDTIME


// Water Options
#define WATER_FANCY
#define WATER_WAVE_TYPE 1 // [0 1 2]
#define WATER_REFRACTION 1 // [0 1]
#define REFRACTION_STRENGTH 100 // [5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 85 100 110 120 130 140 150 160 170 180 190 200]
#define WATER_SCALE 16.0
#define WATER_RADIUS 50
#define WATER_OCTAVES_NEAR 26 // [16 18 20 22 24 26 28 30 32 34 36 38]
#define WATER_OCTAVES_FAR 12
#define WATER_OCTAVES_VERTEX 8
#define WATER_OCTAVES_DIST 120.0
#define WATER_PARALLAX_SAMPLES 64
#define WATER_WAVE_DEPTH 1.0
#define WATER_RESOLUTION 2048
#define WATER_NORMAL_STRENGTH 0.2
#define WATER_ABSROPTION_RATE 1.0
#define VL_WATER_ENABLED
#define VL_WATER_DENSITY 0.04
#define VL_WATER_NOISE


// Atmosphere Options
//#define LIGHTLEAK_FIX
//#define ATMOSFOG_ENABLED
//#define CAVEFOG_ENABLED
#define WEATHER_OPACITY 50 // [10 20 30 40 50 60 70 80 90 100]
#define ATMOS_EXTINCTION 0.004
#define SUN_TEMP 5000.0
#define MOON_TEMP 4000.0
#define WETNESS_MODE 2 // [0 1 2]
#define SNOW_MODE 2 // [0 1 2]
#define VL_SKY_ENABLED
#define VL_SKY_DENSITY 0.02
#define VL_SKY_NOISE


// Shadow Options
#define SHADOW_TYPE 2 // [0 1 2 3]
#define SHADOW_FILTER 1 // [0 1 2]
#define SHADOW_PCF_SIZE 8 // [1 2 3 4 5 6 7 8 9 10 12 14 16 18 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define SHADOW_PCF_SAMPLES 6 // [6 12 24 36]
//#define SHADOW_EXCLUDE_ENTITIES
//#define SHADOW_EXCLUDE_FOLIAGE
//#define SHADOW_COLOR
#define SHADOW_DITHER
#define SHADOW_PARTICLES
#define SHADOW_BIAS_SCALE 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220 230 240 250]
#define SHADOW_DISTORT_FACTOR 0.25 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define SHADOW_ENTITY_CASCADE 1 // [0 1 2 3]
#define SHADOW_CSM_FITRANGE
#define SHADOW_CSM_TIGHTEN
#define SHADOW_PENUMBRA_SCALE 50.0
#define SHADOW_BASIC_BIAS 0.035
//#define SHADOW_DISTORTED_BIAS 0.0016
#define SHADOW_CONTACT 1 // [0 1 2]
#define SHADOW_CSM_FIT_FARSCALE 1.1
#define SHADOW_CSM_FITSCALE 0.1
#define CSM_PLAYER_ID 0


// Material Options
#define MATERIAL_FORMAT 0 // [0 1 2 3]
#define REFLECTION_MODE 2 // [0 1 2]
#define SSR_QUALITY 1 // [0 1 2]
#define SSR_IGNORE_HAND
#define SSS_ENABLED
#define SSS_SCATTER
#define SSS_DITHER
#define SSS_STRENGTH 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define SSS_MAXDIST 7 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
#define SSS_PCF_SIZE 0.08 // [0.02 0.04 0.06 0.08 0.1 0.2 0.3 0.4 0.5 0.6 0.8 1.0]
#define SSS_PCF_SAMPLES 6 // [6 12 24 36]
//#define SSS_NORMALIZE_ALBEDO


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
//#define PARALLAX_DEPTH_WRITE


// Camera Options
#define CAMERA_EXPOSURE_MODE 2 // [0 1 2]
#define CAMERA_EXPOSURE 0 // [-17 -16 -15 -14 -13 -12 -11 -10 -9 -8 -7 -6 -5 -4 -3 -2 -1 0 1 2 3 4 5 6]
#define CAMERA_LUM_MIN 60.0
#define CAMERA_LUM_MAX 64000.0
//#define EXPOSURE_POINT 0.2
#define EXPOSURE_SPEED_UP 1.0
#define EXPOSURE_SPEED_DOWN 0.7
#define TONEMAP 2 // [0 1 2 3 4 5 6 7 8 9 10 11 12]

#define CAMERA_BRIGHTNESS 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define CAMERA_SATURATION 100 // [0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]


// Effect Options
//#define RSM_ENABLED
#define RSM_INTENSITY 9 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
#define RSM_FILTER_SIZE 3.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 4.5 5.0 5.5 6.0 7.0 8.0 10.0 12.0 14.0 16.0]
#define RSM_SAMPLE_COUNT 35 // [35 100 200]
#define RSM_SCALE 2 // [0 1 2]
#define RSM_UPSCALE
#define RSM_DITHER
#define BLOOM_ENABLED
#define BLOOM_SMOOTH
//#define BLOOM_SCALE 60.0
#define BLOOM_THRESHOLD 0.14 // [0.02 0.04 0.06 0.08 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.35 0.40 0.45 0.50]
#define BLOOM_THRESHOLD_WATER 0.12
#define BLOOM_THRESHOLD_NIGHTVISION 0.06
#define BLOOM_POWER 2.4 // [1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0]
#define BLOOM_POWER_WATER 1.6
#define BLOOM_POWER_NIGHTVISION 1.2
#define BLOOM_STRENGTH 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define BLOOM_LOD_MAX 0 // [0 1 2 3 4 5 6 7 8 9]
#define VL_DITHER
#define VL_STRENGTH 100 // [10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 175 200 225 250 275 300 350 400 450 500 600 700 800 900]
#define VL_SAMPLES_SKY 12 // [8 12 16 20 24 32]
#define VL_SAMPLES_WATER 6 // [4 6 8 12 16 24]
#define VL_PARTICLES
#define G_SCATTERING_CLEAR 0.65
#define G_SCATTERING_NIGHT 0.4
//#define G_SCATTERING_HUMID 0.08
#define G_SCATTERING_RAIN 0.1
#define G_SCATTERING_WATER 0.16
#define G_SCATTERING_CLOUDS 0.32
#define G_SCATTERING_RAIN_CLOUDS 0.48
#define AO_TYPE 2 // [0 1 2]
#define SSAO_SAMPLES 8 // [8 16 32]
#define SSAO_INTENSITY 35 // [5 10 15 20 25 30 35 40 45 50]
#define SSAO_SCALE 8.0
#define SSAO_BIAS 0.02
#define SSAO_RADIUS 0.2 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0]
#define SSAO_MAX_DIST 1.6
#define SSAO_UPSCALE

//#define DOF_ENABLED
#define DOF_SCALE 2.0 // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
// Smaller = nicer blur, larger = faster
#define DOF_STEP_SIZE 0.7 // [0.5 1.0 1.5 2.0]
#define DOF_MAX_SIZE 16.0 // [5.0 10.0 15.0 20.0 25.0 30.0]


// Debug Options
#define DEBUG_VIEW 0 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26]
//#define DEBUG_EXPOSURE_METERS
//#define IRIS_FEATURE_CHUNK_OFFSET
#define DITHER_FINAL
#define PARTICLE_OPACITY 0.8
#define PARTICLE_RESOLUTION 8 // [8 16 32 64 128]
//#define PARTICLE_ROUNDING
#define HCM_LAZANYI
#define METAL_AMBIENT 1.0
#define POROSITY_DARKENING 0.8
//#define SHADOW_CONTACT_DITHER
//#define SKY_DITHER
//#define AF_ENABLED
#define AF_SAMPLES 16.0
//#define WATER_REFRACT_HACK
#define CLOUD_HORIZON_POWER 1.0
#define CLOUD_POW_CLEAR 1.6
#define CLOUD_POW_RAIN 0.3
#define SHADOW_CLOUD
#define IRIS_FEATURE_BIOMECAT

#if SSR_QUALITY == 2
    #define SSR_SCALE 1
    #define SSR_MAXSTEPS 512
#elif SSR_QUALITY == 1
    #define SSR_SCALE 2
    #define SSR_MAXSTEPS 256
#else
    #define SSR_SCALE 4
    #define SSR_MAXSTEPS 128
#endif


// INTERNAL
#define TITLE
#define SEA_LEVEL 62
#define CLOUD_LEVEL 200 // [120 130 140 150 160 170 180 190 200 210 220 230 240 250 260]
#define ATMOSPHERE_LEVEL 360
#define WATER_SMOOTH 1.0
#define IOR_AIR 1.000293
#define IOR_WATER 1.333
#define PI 3.1415926538
#define TAU 6.2831853076
#define GOLDEN_ANGLE 2.39996323
#define EPSILON 1e-7
#define GAMMA 2.2

#define attribute in

const float sunLumen = 1.6e9;
const float moonLumen = 800.0;
const float StarLumen = 200.0;
const float EmissionLumens = 100000;

const float SunLux = 64000.0;
const float SunOvercastLux = 48000.0;
const float MoonLux = 26.0;
const float MoonOvercastLux = 4.0;
const float BlockLightLux = 3200.0;
// const float MinWorldLux = 8.0;

const float DaySkyLumen = 6400.0;
const float DaySkyOvercastLumen = 3200.0;
const float NightSkyLumen = 4.0;
const float NightSkyOvercastLumen = 1.0;

const vec3 FOG_RAIN_COLOR = vec3(0.839, 0.843, 0.824)*0.2;
const vec4 WATER_COLOR = vec4(0.139, 0.271, 0.313, 0.1);
const vec3 CLOUD_COLOR = vec3(0.248, 0.225, 0.273);
const vec3 SNOW_COLOR = vec3(0.590, 0.665, 0.682);
const vec3 POWDER_SNOW_COLOR = vec3(0.820, 0.868, 0.879);

const vec3 minLight = vec3(0.01);
const float tile_dist_bias_factor = 0.012288;
const vec3 handOffsetMain = vec3(0.6, -0.3, -0.2);
const vec3 handOffsetAlt = vec3(-0.6, -0.3, -0.2);
const vec3 luma_factor = vec3(0.2126, 0.7152, 0.0722);
const float invPI = 1.0 / PI;

const float wetnessHalflife = 300.0;
const float drynessHalflife = 10.0;

#if MC_VERSION < 11700 || SHADER_PLATFORM == PLATFORM_IRIS
    const float alphaTestRef = 0.1;
#endif

// #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
//     #undef PARALLAX_ENABLED
// #endif

// #ifdef PARALLAX_ENABLED
//     #ifdef PARALLAX_SMOOTH
//         #undef PARALLAX_SLOPE_NORMALS
//     #else
//         #undef PARALLAX_SMOOTH_NORMALS
//     #endif
// #else
//     #undef PARALLAX_SMOOTH
//     #undef PARALLAX_SMOOTH_NORMALS
//     #undef PARALLAX_SLOPE_NORMALS
//     #undef PARALLAX_SHADOWS_ENABLED
// #endif

// #if !defined SHADOW_ENABLED || SHADOW_TYPE == 0
//     #undef RSM_ENABLED
//     //#undef SSS_ENABLED
//     #undef VL_ENABLED
// #endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    #define SHADOW_POS_TYPE vec3 shadowPos[4]
#else
    #define SHADOW_POS_TYPE vec4 shadowPos
#endif

// #if SHADOW_TYPE == 3
//     // VL is not currently supported with CSM
//     #undef VL_ENABLED
// #endif

// #if !defined RSM_ENABLED || RSM_SCALE == 0
//     #undef RSM_UPSCALE
// #endif

#ifdef REFLECTION_MODE
#endif
#ifdef WATER_WAVE_TYPE
#endif
#ifdef WATER_REFRACTION
#endif
#ifdef CAVEFOG_ENABLED
#endif
#ifdef ATMOSFOG_ENABLED
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
#ifdef SHADOW_CSM_FITRANGE
#endif
#ifdef SHADOW_CSM_TIGHTEN
#endif
#ifdef SHADOW_PARTICLES
#endif
#ifdef RSM_ENABLED
#endif
#ifdef RSM_SCALE
#endif
#ifdef RSM_UPSCALE
#endif
// #ifdef VL_SKY_ENABLED
// #endif
// #ifdef VL_WATER_ENABLED
// #endif
#ifdef VL_PARTICLES
#endif
#ifdef VL_DITHER
#endif
#ifdef SSS_NORMALIZE_ALBEDO
#endif
#ifdef DOF_ENABLED
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
