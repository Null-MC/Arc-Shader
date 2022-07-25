//#extension GL_ARB_shading_language_packing : enable
#extension GL_ARB_texture_query_levels : enable

#define RENDER_FINAL


#ifdef RENDER_VERTEX
    out vec2 texcoord;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        flat out int luminanceLod;
        flat out float averageLuminance;
        flat out float EV100;

        uniform sampler2D BUFFER_HDR_PREVIOUS;

        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    uniform float screenBrightness;
    uniform int heldBlockLightValue;
    
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #ifdef BLOOM_ENABLED
        flat out int bloomTileCount;

        uniform sampler2D BUFFER_HDR;

        #include "/lib/camera/bloom.glsl"
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #ifdef BLOOM_ENABLED
            bloomTileCount = GetBloomTileCount();
        #endif

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            luminanceLod = GetLuminanceLod();
        #endif

        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            averageLuminance = GetAverageLuminance();
            EV100 = GetEV100(averageLuminance);
        #endif
    }
#endif

#ifdef RENDER_FRAG
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
    
    #if DEBUG_VIEW == DEBUG_VIEW_GBUFFER_COLOR
        // Deferred Color
        uniform usampler2D BUFFER_DEFERRED;
    #elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_NORMAL
        // Deferred Normal
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
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_ALBEDO
        // Shadow Color
        uniform sampler2D shadowcolor0;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_NORMAL
        // Shadow Normal
        uniform usampler2D shadowcolor1;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_SSS
        // Shadow SSS
        uniform usampler2D shadowcolor1;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH0
        // Shadow Depth [0]
        uniform sampler2D shadowtex0;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH1
        // Shadow Depth [1]
        uniform sampler2D shadowtex1;
    #elif DEBUG_VIEW == DEBUG_VIEW_HDR
        // HDR
        uniform sampler2D BUFFER_HDR;
    #elif DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
        // Luminance
        uniform sampler2D BUFFER_LUMINANCE;
    #elif DEBUG_VIEW == DEBUG_VIEW_RSM
        // RSM
        uniform sampler2D BUFFER_RSM_COLOR;
    #elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
        // Bloom Tiles
        uniform sampler2D BUFFER_BLOOM;
    #elif DEBUG_VIEW == DEBUG_VIEW_PREV_COLOR
        // Previous HDR Color
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #elif DEBUG_VIEW == DEBUG_VIEW_PREV_LUMINANCE
        // Previous Luminance
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #elif DEBUG_VIEW == DEBUG_VIEW_WATER_WAVES
        // Water Waves
        uniform sampler2D BUFFER_WATER_WAVES;
    #else
        uniform sampler2D BUFFER_HDR;

        #ifdef BLOOM_ENABLED
            uniform sampler2D BUFFER_BLOOM;

            #include "/lib/camera/bloom.glsl"
        #endif

        #include "/lib/camera/tonemap.glsl"
    #endif

    /* RENDERTARGETS: 0 */
    out vec3 outColor0;


    #ifdef DEBUG_EXPOSURE_METERS
        void RenderLuminanceMeters(inout vec3 color, const in float avgLum, const in float EV100) {
            if (gl_FragCoord.x < 8) {
                float avgLumScaled = clamp(avgLum * (1.0/160000.0), 0.0, 1.0);
                color = vec3(1.0, 0.0, 0.0) * step(texcoord.y, sqrt(avgLumScaled));
            }
            else if (gl_FragCoord.x < 16) {
                color = vec3(0.0, 1.0, 0.0) * step(texcoord.y, (EV100 + 1.0) / 20.0);

                vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
                if (abs(texcoord.y - (2.0 / 15.0)) < 2.0 * pixelSize.y)
                    color = vec3(1.0, 1.0, 1.0);
            }
        }
    #endif

    #if DEBUG_VIEW == 0
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
            ivec2 itex = ivec2(texcoord * vec2(viewWidth, viewHeight));
            vec3 color = texelFetch(BUFFER_HDR, itex, 0).rgb;// * exposure;

            #ifdef BLOOM_ENABLED
                vec3 bloom = vec3(0.0);
                for (int i = 0; i < bloomTileCount; i++) {
                    vec2 tileMin, tileMax;
                    GetBloomTileInnerBounds(i, tileMin, tileMax);

                    vec2 tileTex = texcoord * (tileMax - tileMin) + tileMin;
                    tileTex = clamp(tileTex, tileMin, tileMax);

                    bloom += textureLod(BUFFER_BLOOM, tileTex, 0).rgb;
                }

                color += bloom * (0.01 * BLOOM_STRENGTH);
            #endif

            float whitePoint = 1.0;
            color = ApplyTonemap(color, whitePoint);

            //mat4 matSaturation = GetSaturationMatrix(1.5);
            //color = mat3(matSaturation) * color;

            color = TonemapLinearToRGB(color);

            #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
                RenderLuminanceMeters(color, averageLuminance, EV100);
            #endif

            return color;
        }
    #endif

    void main() {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        ivec2 iuv = ivec2(texcoord * viewSize);

        vec3 color = vec3(0.0);
        #if DEBUG_VIEW == DEBUG_VIEW_GBUFFER_COLOR
            // Deferred Color
            uint deferredDataR = texture(BUFFER_DEFERRED, texcoord).r;
            color = unpackUnorm4x8(deferredDataR).rgb;
        #elif DEBUG_VIEW == DEBUG_VIEW_GBUFFER_NORMAL
            // Deferred Normal
            uint deferredDataG = texelFetch(BUFFER_DEFERRED, iuv, 0).g;
            color.rg = unpackUnorm4x8(deferredDataG).rg;
            color.b = 0.0;
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
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_ALBEDO
            // Shadow Color
            color = textureLod(shadowcolor0, texcoord, 0).rgb;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_NORMAL
            // Shadow Normal
            uint data = textureLod(shadowcolor1, texcoord, 0).g;
            vec2 normalXY = unpackUnorm4x8(data).rg;
            color = RestoreNormalZ(normalXY) * 0.5 + 0.5;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_SSS
            // Shadow SSS
            uint data = textureLod(shadowcolor1, texcoord, 0).g;
            color = unpackUnorm4x8(data).bbb;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH0
            // Shadow Depth [0]
            color = texture(shadowtex0, texcoord).rrr;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH1
            // Shadow Depth [1]
            color = texture(shadowtex1, texcoord).rrr;
        #elif DEBUG_VIEW == DEBUG_VIEW_HDR
            // HDR
            color = texture(BUFFER_HDR, texcoord).rgb;
        #elif DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
            // Luminance
            float logLum = textureLod(BUFFER_LUMINANCE, texcoord, 0).r;
            color = vec3(exp2(logLum) - EPSILON) * 1e-4;

            #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
                RenderLuminanceMeters(color, averageLuminance, EV100);
            #endif
        #elif DEBUG_VIEW == DEBUG_VIEW_RSM
            // RSM
            #if RSM_SCALE == 0 || defined RSM_UPSCALE
                color = texelFetch(BUFFER_RSM_COLOR, iuv, 0).rgb;
            #else
                const float rsm_scale = 1.0 / exp2(RSM_SCALE);
                color = textureLod(BUFFER_RSM_COLOR, texcoord * rsm_scale, 0).rgb;
            #endif
        #elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
            // Bloom Tiles
            color = texture(BUFFER_BLOOM, texcoord).rgb;
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
            color = vec3(exp2(logLum) - EPSILON) * 1e-5;

            #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
                RenderLuminanceMeters(color, averageLuminance, EV100);
            #endif
        #elif DEBUG_VIEW == DEBUG_VIEW_WATER_WAVES
            // Water Waves
            color = textureLod(BUFFER_WATER_WAVES, texcoord, 0).rrr;
        #else
            // None
            color = GetFinalColor();
        #endif

        outColor0 = color;
    }
#endif
