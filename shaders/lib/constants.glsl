#define BLOCK_OUTLINE_NONE 0
#define BLOCK_OUTLINE_BLACK 1
#define BLOCK_OUTLINE_WHITE 2
#define BLOCK_OUTLINE_FANCY 3

#define WATER_REFRACTION_NONE 0
#define WATER_REFRACTION_FAST 1
#define WATER_REFRACTION_FANCY 2

#define WATER_WAVE_NONE 0
#define WATER_WAVE_VERTEX 1
#define WATER_WAVE_PARALLAX 2

#define ATMOSPHERE_TYPE_FAST 0
#define ATMOSPHERE_TYPE_FANCY 1

#define MATERIAL_FORMAT_DEFAULT 0
#define MATERIAL_FORMAT_LABPBR 1
#define MATERIAL_FORMAT_OLDPBR 2
#define MATERIAL_FORMAT_PATRIX 3

#define REFLECTION_MODE_NONE 0
#define REFLECTION_MODE_SKY 1
#define REFLECTION_MODE_SCREEN 2

#define SHADOW_TYPE_NONE 0
#define SHADOW_TYPE_BASIC 1
#define SHADOW_TYPE_DISTORTED 2
#define SHADOW_TYPE_CASCADED 3

#define EXPOSURE_MODE_MANUAL 0
#define EXPOSURE_MODE_EYEBRIGHTNESS 1
#define EXPOSURE_MODE_MIPMAP 2
#define EXPOSURE_MODE_HISTOGRAM 3

#define DEBUG_VIEW_GBUFFER_COLOR 1
#define DEBUG_VIEW_GBUFFER_NORMAL 2
#define DEBUG_VIEW_GBUFFER_SPECULAR 3
#define DEBUG_VIEW_GBUFFER_LIGHTING 4
#define DEBUG_VIEW_GBUFFER_SHADOW 5
#define DEBUG_VIEW_SHADOW_COLOR 6
#define DEBUG_VIEW_SHADOW_SSS 7
#define DEBUG_VIEW_SHADOW_DEPTH0 8
#define DEBUG_VIEW_SHADOW_DEPTH1 9
#define DEBUG_VIEW_HDR 10
#define DEBUG_VIEW_LUMINANCE 11
#define DEBUG_VIEW_RSM_COLOR 12
#define DEBUG_VIEW_RSM_NORMAL 13
#define DEBUG_VIEW_RSM_FINAL 14
#define DEBUG_VIEW_BLOOM 15
#define DEBUG_VIEW_PREV_COLOR 16
#define DEBUG_VIEW_PREV_LUMINANCE 17
#define DEBUG_VIEW_WATER_WAVES 18

#define BUFFER_DEFERRED colortex2
#define BUFFER_DEFERRED2 colortex3
#define BUFFER_HDR colortex4
#define BUFFER_HDR_PREVIOUS colortex5
#define BUFFER_LUMINANCE colortex6
#define BUFFER_BLOOM colortex7
#define BUFFER_RSM_COLOR colortex8
#define BUFFER_RSM_DEPTH colortex9
#define BUFFER_BRDF_LUT colortex10
#define BUFFER_WATER_WAVES colortex11

#define BUFFER_REFRACT colortex7
