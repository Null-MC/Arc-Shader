#define RENDER_FINAL
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
//flat in float exposure;

#ifdef BLOOM_ENABLED
    flat in int bloomTileCount;
#endif

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
    flat in int luminanceLod;
#endif

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    flat in float averageLuminance;
    flat in float EV100;
#endif

uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

#include "/lib/depth.glsl"

#if DEBUG_VIEW == DEBUG_VIEW_GBUFFER_COLOR
    // Deferred Color
    uniform usampler2D BUFFER_DEFERRED;
#elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_NORMAL
    // Deferred Normal
    uniform usampler2D BUFFER_DEFERRED;
    uniform mat4 gbufferModelViewInverse;
#elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_OCCLUSION
    // Deferred Occlusion
    uniform usampler2D BUFFER_DEFERRED;
#elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_SPECULAR
    // Deferred Specular
    uniform usampler2D BUFFER_DEFERRED;
#elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_LIGHTING
    // Deferred Lighting
    uniform usampler2D BUFFER_DEFERRED;
#elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_SHADOW
    // Deferred Shadow
    uniform sampler2D BUFFER_DEFERRED2;
#elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_COLOR
    // Shadow Color
    uniform sampler2D shadowcolor0;
#elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_NORMAL
    // Shadow Normal
    uniform usampler2D shadowcolor1;
#elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_SSS
    // Shadow SSS
    #ifdef SHADOW_COLOR
        uniform usampler2D shadowcolor1;
    #else
        uniform sampler2D shadowcolor0;
    #endif
#elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH0
    // Shadow Depth [0]
    uniform sampler2D shadowtex0;
#elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH1
    // Shadow Depth [1]
    uniform sampler2D shadowtex1;
#elif DEBUG_VIEW == DEBUG_VIEW_HDR
    // HDR
    uniform sampler2D BUFFER_HDR_OPAQUE;
#elif DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
    // Luminance
    uniform sampler2D BUFFER_LUM_OPAQUE;
#elif DEBUG_VIEW == DEBUG_VIEW_RSM_COLOR
    // RSM Color
    uniform usampler2D shadowcolor1;
#elif DEBUG_VIEW == DEBUG_VIEW_RSM_NORMAL
    // RSM Normal
    uniform usampler2D shadowcolor1;
#elif DEBUG_VIEW == DEBUG_VIEW_RSM_FINAL
    // RSM Final
    uniform sampler2D BUFFER_RSM_COLOR;

    #ifdef RSM_UPSCALE
        uniform sampler2D BUFFER_RSM_DEPTH;
        uniform sampler2D depthtex0;

        #include "/lib/sampling/bilateral_gaussian.glsl"
    #endif
#elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
    // Bloom Tiles
    uniform sampler2D BUFFER_BLOOM;
#elif DEBUG_VIEW == DEBUG_VIEW_PREV_COLOR
    // Previous HDR Color
    uniform sampler2D BUFFER_HDR_PREVIOUS;
#elif DEBUG_VIEW == DEBUG_VIEW_PREV_LUMINANCE
    // Previous Luminance
    uniform sampler2D BUFFER_HDR_PREVIOUS;
#elif DEBUG_VIEW == DEBUG_VIEW_PREV_DEPTH
    // Previous HDR Depth
    uniform sampler2D BUFFER_DEPTH_PREV;
#elif DEBUG_VIEW == DEBUG_VIEW_DEPTH_TILES
    // Depth Tiles
    uniform sampler2D BUFFER_DEPTH_PREV;
#elif DEBUG_VIEW == DEBUG_VIEW_A0
    // Ambient Occlusion
    uniform sampler2D BUFFER_AO;

    #ifdef SSAO_UPSCALE
        uniform sampler2D depthtex0;
        uniform sampler2D depthtex1;

        #include "/lib/sampling/bilateral_gaussian.glsl"
    #endif
#elif DEBUG_VIEW == DEBUG_VIEW_LUT_BRDF
    // BRDF LUT
    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler2D texBRDF;
    #else
        uniform sampler2D colortex14;
    #endif
#elif DEBUG_VIEW == DEBUG_VIEW_LUT_SUN_TRANSMISSION
    // Sun Transmission LUT
    uniform float rainStrength;
    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
    #else
        uniform sampler3D colortex11;
    #endif
#elif DEBUG_VIEW == DEBUG_VIEW_LUT_SKY
    // Sky LUT
    uniform sampler2D BUFFER_SKY_LUT;
#else
    uniform float frameTimeCounter;
    uniform float aspectRatio;
    uniform int isEyeInWater;

    uniform sampler2D BUFFER_HDR_OPAQUE;

    #ifdef BLOOM_ENABLED
        uniform sampler2D BUFFER_BLOOM;

        #include "/lib/camera/bloom.glsl"
    #endif

    #include "/lib/sampling/bayer.glsl"
    #include "/lib/camera/tonemap.glsl"
    #include "/lib/camera/wetness.glsl"
#endif

vec2 viewSize;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outColor0;


#ifdef DEBUG_EXPOSURE_METERS
    void RenderLuminanceMeters(inout vec3 color, const in float avgLum, const in float EV100) {
        if (gl_FragCoord.x < 8) {
            float avgLumScaled = clamp(avgLum / CAMERA_LUM_MAX, 0.0, 1.0);
            color = vec3(1.0, 0.0, 0.0) * step(texcoord.y, sqrt(avgLumScaled));
        }
        else if (gl_FragCoord.x < 16) {
            color = vec3(0.0, 1.0, 0.0) * step(texcoord.y, (EV100 + 2.0) / 16.0);

            vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
            if (abs(texcoord.y - (2.0 / 16.0)) < 2.0 * pixelSize.y)
                color = vec3(1.0, 1.0, 1.0);
        }
    }
#endif

#if DEBUG_VIEW == DEBUG_VIEW_NONE || DEBUG_VIEW == DEBUG_VIEW_WHITEWORLD
    mat4 GetSaturationMatrix(const in float saturation) {
        const vec3 luminance = vec3(0.3086, 0.6094, 0.0820);
        
        float oneMinusSat = 1.0 - saturation;
        vec3 red = vec3(luminance.x * oneMinusSat) + vec3(saturation, 0.0, 0.0);
        vec3 green = vec3(luminance.y * oneMinusSat) + vec3(0.0, saturation, 0.0);
        vec3 blue = vec3(luminance.z * oneMinusSat) + vec3(0.0, 0.0, saturation);
        
        return mat4(red,           0.0,
                    green,         0.0,
                    blue,          0.0,
                    0.0, 0.0, 0.0, 1.0);
    }

    vec3 GetFinalColor() {
        vec2 texFinal = texcoord;

        //if (isEyeInWater == 1)
        //    texFinal = GetWetnessSkew(texcoord);

        vec3 color = MC_RENDER_QUALITY == 1.0
            ? texelFetch(BUFFER_HDR_OPAQUE, ivec2(texFinal * viewSize), 0).rgb
            : textureLod(BUFFER_HDR_OPAQUE, texFinal, 0).rgb;

        //float lum = texelFetch(BUFFER_LUMINANCE, itex, 0).r;

        #ifdef BLOOM_ENABLED
            vec3 bloom = vec3(0.0);
            for (int i = 0; i < bloomTileCount; i++) {
                vec2 tileMin, tileMax;
                GetBloomTileInnerBounds(i, tileMin, tileMax);

                vec2 tileTex = texFinal * (tileMax - tileMin) + tileMin;
                tileTex = clamp(tileTex, tileMin, tileMax);

                bloom += textureLod(BUFFER_BLOOM, tileTex, 0).rgb;
            }

            bloom *= (0.01 * BLOOM_STRENGTH);
            color += bloom;// / sqrt(bloomTileCount);
        #endif

        float whitePoint = 1.0;
        color = ApplyTonemap(color, whitePoint);

        #if CAMERA_SATURATION != 100
            mat4 matSaturation = GetSaturationMatrix(CAMERA_SATURATION * 0.01);
            color = mat3(matSaturation) * color;
        #endif

        color = TonemapLinearToRGB(color);

        #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            RenderLuminanceMeters(color, averageLuminance, EV100);
        #endif

        #ifdef DITHER_FINAL
            float b = GetScreenBayerValue();
            color *= (254.0/255.0) + b * (2.0/255.0);
        #endif

        return color;
    }
#endif

void main() {
    viewSize = vec2(viewWidth, viewHeight);
    ivec2 iuv = ivec2(texcoord * viewSize);

    vec3 color = vec3(0.0);
    #if DEBUG_VIEW == DEBUG_VIEW_GBUFFER_COLOR
        // Deferred Color
        uint deferredDataR = texelFetch(BUFFER_DEFERRED, iuv, 0).r;
        color = unpackUnorm4x8(deferredDataR).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_NORMAL
        // Deferred Normal
        uint deferredDataG = texelFetch(BUFFER_DEFERRED, iuv, 0).g;
        vec3 normal = unpackUnorm4x8(deferredDataG).rgb;
        if (any(greaterThan(normal, vec3(0.0)))) {
            normal = normal * 2.0 - 1.0;
            normal = mat3(gbufferModelViewInverse) * normal;
            normal = normal * 0.5 + 0.5;
        }
        color = normal;
    #elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_OCCLUSION
        // Deferred Occlusion
        uint deferredDataG = texelFetch(BUFFER_DEFERRED, iuv, 0).g;
        color = unpackUnorm4x8(deferredDataG).aaa;
    #elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_SPECULAR
        // Deferred Specular
        uint deferredDataB = texelFetch(BUFFER_DEFERRED, iuv, 0).b;
        color = unpackUnorm4x8(deferredDataB).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_LIGHTING
        // Deferred Lighting
        uint deferredDataA = texelFetch(BUFFER_DEFERRED, iuv, 0).a;
        color = unpackUnorm4x8(deferredDataA).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_SHADOW
        // Deferred Shadow
        color = texelFetch(BUFFER_DEFERRED2, iuv, 0).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_COLOR
        // Shadow Color
        color = textureLod(shadowcolor0, texcoord, 0).rgb;
        color = LinearToRGB(color);
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_NORMAL
        // Shadow Normal
        uint data = textureLod(shadowcolor1, texcoord, 0).g;
        color = unpackUnorm4x8(data).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_SSS
        // Shadow SSS
        #ifdef SHADOW_COLOR
            uint data = textureLod(shadowcolor1, texcoord, 0).g;
            color = unpackUnorm4x8(data).aaa;
        #else
            color = textureLod(shadowcolor0, texcoord, 0).rrr;
        #endif
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH0
        // Shadow Depth [0]
        color = textureLod(shadowtex0, texcoord, 0).rrr;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH1
        // Shadow Depth [1]
        color = textureLod(shadowtex1, texcoord, 0).rrr;
    #elif DEBUG_VIEW == DEBUG_VIEW_HDR
        // HDR
        color = textureLod(BUFFER_HDR_OPAQUE, texcoord, 0).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
        // Luminance
        float logLum = textureLod(BUFFER_LUM_OPAQUE, texcoord, 0).r;
        float lum = exp2(logLum) - EPSILON;
        color = vec3(lum * 1e-6);

        #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            RenderLuminanceMeters(color, averageLuminance, EV100);
        #endif
    #elif DEBUG_VIEW == DEBUG_VIEW_RSM_COLOR
        // RSM Color
        uint data = textureLod(shadowcolor1, texcoord, 0).r;
        color = unpackUnorm4x8(data).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_RSM_NORMAL
        // RSM Normal
        uint data = textureLod(shadowcolor1, texcoord, 0).g;
        vec2 normalXY = unpackUnorm4x8(data).rg;
        color = RestoreNormalZ(normalXY) * 0.5 + 0.5;
    #elif DEBUG_VIEW == DEBUG_VIEW_RSM_FINAL
        // RSM Final
        //color = textureLod(BUFFER_RSM_COLOR, texcoord, 0).rgb;
        #ifdef RSM_UPSCALE
            vec2 rsmViewSize = viewSize / exp2(RSM_SCALE);
            float clipDepth = texelFetch(depthtex0, iuv, 0).r;
            clipDepth = linearizeDepthFast(clipDepth, near, far);
            color = BilateralGaussianDepthBlurRGB_5x(BUFFER_RSM_COLOR, rsmViewSize, BUFFER_RSM_DEPTH, rsmViewSize, clipDepth, 0.2);
        #else
            color = textureLod(BUFFER_RSM_COLOR, texcoord, 0).rgb;
        #endif
    #elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
        // Bloom Tiles
        color = textureLod(BUFFER_BLOOM, texcoord, 0).rgb;
        color = LinearToRGB(color);
    #elif DEBUG_VIEW == DEBUG_VIEW_PREV_COLOR
        // Previous HDR Color
        color = textureLod(BUFFER_HDR_PREVIOUS, texcoord, 0).rgb;
    #elif DEBUG_VIEW == DEBUG_VIEW_PREV_LUMINANCE
        // Previous Luminance
        int lod = 0;

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            if (texcoord.x >= 0.5) lod = luminanceLod-2;
        #endif

        float logLum = textureLod(BUFFER_HDR_PREVIOUS, texcoord, lod).a;
        color = vec3(exp2(logLum) - EPSILON) * 1e-4;

        #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            RenderLuminanceMeters(color, averageLuminance, EV100);
        #endif
    #elif DEBUG_VIEW == DEBUG_VIEW_PREV_DEPTH
        // Previous HDR Depth
        float depth = textureLod(BUFFER_DEPTH_PREV, texcoord, 0).r;
        color = vec3(linearizeDepthFast(depth, near, far) / far);
    #elif DEBUG_VIEW == DEBUG_VIEW_DEPTH_TILES
        // Prev Depth Tiles
        color = textureLod(BUFFER_DEPTH_PREV, texcoord, 0).rrr;
    #elif DEBUG_VIEW == DEBUG_VIEW_A0
        // Ambient Occlusion
        #ifdef SSAO_UPSCALE
            ivec2 iTex = ivec2(gl_FragCoord.xy);
            float opaqueScreenDepth = texelFetch(depthtex1, iTex, 0).r;
            float opaqueScreenDepthLinear = linearizeDepthFast(opaqueScreenDepth, near, far);
            float occlusion = BilateralGaussianDepthBlur_9x(BUFFER_AO, 0.5 * viewSize, depthtex0, viewSize, opaqueScreenDepthLinear, 0.9);
            color = vec3(occlusion);
        #else
            color = textureLod(BUFFER_AO, texcoord, 0).rrr;
        #endif
    #elif DEBUG_VIEW == DEBUG_VIEW_LUT_BRDF
        // BRDF LUT
        #if SHADER_PLATFORM == PLATFORM_IRIS
            color.rg = textureLod(texBRDF, texcoord, 0).rg;
        #else
            color.rg = textureLod(colortex14, texcoord, 0).rg;
        #endif
        color.b = 0.0;
    #elif DEBUG_VIEW == DEBUG_VIEW_LUT_SUN_TRANSMISSION
        // Sun Transmission LUT
        vec3 t3 = vec3(texcoord, rainStrength);
        #if SHADER_PLATFORM == PLATFORM_IRIS
            color = textureLod(texSunTransmittance, t3, 0).rgb;
        #else
            color = textureLod(colortex11, t3, 0).rgb;
        #endif
    #elif DEBUG_VIEW == DEBUG_VIEW_LUT_SKY
        // Sky LUT
        color = textureLod(BUFFER_SKY_LUT, texcoord, 0).rgb;
    #else
        // None
        color = GetFinalColor();
    #endif

    outColor0 = color;
}
