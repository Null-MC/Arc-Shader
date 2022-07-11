//#extension GL_ARB_shading_language_packing : enable
#extension GL_ARB_texture_query_levels : enable

#define RENDER_FINAL


#ifdef RENDER_VERTEX
    out vec2 texcoord;
    //flat out float exposure;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP //&& DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
        flat out int luminanceLod;
    #endif

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        flat out float averageLuminance;
        flat out float EV100;
    #endif

    #ifdef BLOOM_ENABLED
        flat out int bloomTileCount;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightnessSmooth;
    #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    uniform int heldBlockLightValue;
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #ifdef BLOOM_ENABLED
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

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP //DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
        flat in int luminanceLod;
    #endif

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        flat in float averageLuminance;
        flat in float EV100;
    #endif

    uniform float viewWidth;
    uniform float viewHeight;
    
    #if DEBUG_VIEW == DEBUG_VIEW_SHADOW_ALBEDO
        // Shadow Albedo
        uniform usampler2D shadowcolor0;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_NORMAL
        // Shadow Normal
        uniform usampler2D shadowcolor0;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_SSS
        // Shadow SSS
        uniform usampler2D shadowcolor0;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH0
        // Shadow Depth [0]
        uniform sampler2D shadowtex0;
    #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH1
        // Shadow Depth [1]
        uniform sampler2D shadowtex1;
    #elif DEBUG_VIEW == DEBUG_VIEW_RSM
        // RSM
        uniform sampler2D BUFFER_RSM_COLOR;
    #elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
        // Bloom Tiles
        uniform sampler2D BUFFER_BLOOM;
    #elif DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
        // Luminance
        uniform sampler2D BUFFER_LUMINANCE;
    #elif DEBUG_VIEW == DEBUG_VIEW_PREV_COLOR
        // Previous HDR Color
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #elif DEBUG_VIEW == DEBUG_VIEW_PREV_LUMINANCE
        // Previous Luminance
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #else
        uniform sampler2D BUFFER_HDR;

        //uniform float screenBrightness;

        #ifdef BLOOM_ENABLED
            uniform sampler2D BUFFER_BLOOM;

            #include "/lib/camera/bloom.glsl"
        #endif

        //#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        //    uniform sampler2D BUFFER_LUMINANCE;
        //#endif

        //#include "/lib/camera/exposure.glsl"
        #include "/lib/camera/tonemap.glsl"
    #endif


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
                    //bloom += clamp(sample, 0.0, 1.0);
                }

                //float lum = luminance(bloom);
                //color /= 1.0 + lum;

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
        vec3 color = vec3(0.0);
        #if DEBUG_VIEW == DEBUG_VIEW_SHADOW_ALBEDO
            // Shadow Albedo
            uint data = texture(shadowcolor0, texcoord).r;
            color = unpackUnorm4x8(data).rgb;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_NORMAL
            // Shadow Normal
            uint data = texture(shadowcolor0, texcoord).g;
            color = RestoreNormalZ(unpackUnorm2x16(data)) * 0.5 + 0.5;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_SSS
            // Shadow SSS
            uint data = texture(shadowcolor0, texcoord).r;
            color = unpackUnorm4x8(data).aaa;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH0
            // Shadow Depth [0]
            color = texture(shadowtex0, texcoord).rrr;
        #elif DEBUG_VIEW == DEBUG_VIEW_SHADOW_DEPTH1
            // Shadow Depth [1]
            color = texture(shadowtex1, texcoord).rrr;
        #elif DEBUG_VIEW == DEBUG_VIEW_RSM
            // RSM
            vec2 viewSize = vec2(viewWidth, viewHeight);

            #if RSM_SCALE == 0 || defined RSM_UPSCALE
                ivec2 iuv = ivec2(texcoord * viewSize);
                color = texelFetch(BUFFER_RSM_COLOR, iuv, 0).rgb;
            #else
                const float rsm_scale = 1.0 / exp2(RSM_SCALE);
                color = textureLod(BUFFER_RSM_COLOR, texcoord * rsm_scale, 0).rgb;
            #endif
        #elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
            // Bloom Tiles
            color = texture(BUFFER_BLOOM, texcoord).rgb;
        #elif DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
            // Luminance
            float logLum = textureLod(BUFFER_LUMINANCE, texcoord, 0).a;
            color = vec3(exp(logLum) - EPSILON) * 1e-5;

            #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
                RenderLuminanceMeters(color, averageLuminance, EV100);
            #endif
        #elif DEBUG_VIEW == DEBUG_VIEW_PREV_COLOR
            // Previous HDR Color
            color = textureLod(BUFFER_HDR_PREVIOUS, texcoord, 0).rgb;
        #elif DEBUG_VIEW == DEBUG_VIEW_PREV_LUMINANCE
            // Previous Luminance
            int lod = texcoord.x < 0.5 ? 0 : luminanceLod;
            float logLum = textureLod(BUFFER_HDR_PREVIOUS, texcoord, lod).a;
            color = vec3(exp(logLum) - EPSILON) * 1e-5;

            #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
                RenderLuminanceMeters(color, averageLuminance, EV100);
            #endif
        #else
            // None
            color = GetFinalColor();
        #endif

    /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(color, 1.0);
    }
#endif
