#define PLATFORM_OPTIFINE 0
#define PLATFORM_IRIS 1

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

#define WEATHER_MODE_NONE 0
#define WEATHER_MODE_SKY 1
#define WEATHER_MODE_FULL 2

#define AO_TYPE_NONE 0
#define AO_TYPE_VANILLA 1
#define AO_TYPE_SS 2

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

#define SHADOW_CONTACT_NONE 0
#define SHADOW_CONTACT_FAR 1
#define SHADOW_CONTACT_ALL 2

#define EXPOSURE_MODE_MANUAL 0
#define EXPOSURE_MODE_EYEBRIGHTNESS 1
#define EXPOSURE_MODE_MIPMAP 2
#define EXPOSURE_MODE_HISTOGRAM 3

#define DEBUG_VIEW_NONE 0
#define DEBUG_VIEW_GBUFFER_COLOR 1
#define DEBUG_VIEW_GBUFFER_NORMAL 2
#define DEBUG_VIEW_GBUFFER_OCCLUSION 3
#define DEBUG_VIEW_GBUFFER_SPECULAR 4
#define DEBUG_VIEW_GBUFFER_LIGHTING 5
#define DEBUG_VIEW_GBUFFER_SHADOW 6
#define DEBUG_VIEW_SHADOW_COLOR 7
#define DEBUG_VIEW_SHADOW_NORMAL 8
#define DEBUG_VIEW_SHADOW_SSS 9
#define DEBUG_VIEW_SHADOW_DEPTH0 10
#define DEBUG_VIEW_SHADOW_DEPTH1 11
#define DEBUG_VIEW_HDR 12
#define DEBUG_VIEW_LUMINANCE 13
#define DEBUG_VIEW_RSM_COLOR 14
#define DEBUG_VIEW_RSM_NORMAL 15
#define DEBUG_VIEW_RSM_FINAL 16
#define DEBUG_VIEW_BLOOM 17
#define DEBUG_VIEW_PREV_COLOR 18
#define DEBUG_VIEW_PREV_LUMINANCE 19
#define DEBUG_VIEW_PREV_DEPTH 20
#define DEBUG_VIEW_WATER_WAVES 21
#define DEBUG_VIEW_DEPTH_TILES 22
#define DEBUG_VIEW_A0 23
#define DEBUG_VIEW_LUT_BRDF 24
#define DEBUG_VIEW_LUT_SUN_TRANSMISSION 25
#define DEBUG_VIEW_WHITEWORLD 26

#define BUFFER_DEFERRED colortex2
#define BUFFER_AO colortex3
#define BUFFER_HDR colortex4
#define BUFFER_HDR_PREVIOUS colortex5
#define BUFFER_LUMINANCE colortex6
#define BUFFER_BLOOM colortex7
#define BUFFER_REFRACT colortex7
#define BUFFER_RSM_COLOR colortex8
#define BUFFER_RSM_DEPTH colortex9
#define BUFFER_BRDF_LUT colortex10
#define BUFFER_WATER_WAVES colortex11
#define BUFFER_DEPTH_PREV colortex12

#define MATERIAL_WATER 100
#define MATERIAL_NETHER_PORTAL 102
#define MATERIAL_LAVA 110

#define MATERIAL_LIGHTNING_BOLT 100
#define MATERIAL_ITEM_FRAME 101
#define MATERIAL_PHYSICS_SNOW 102
