//#extension GL_ARB_shading_language_packing : enable
#extension GL_ARB_texture_query_levels : enable

#define RENDER_FINAL


#ifdef RENDER_VERTEX
    out vec2 texcoord;
    flat out float exposure;

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
        uniform sampler2D BUFFER_LUMINANCE;
    #endif

    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;

    #ifdef BLOOM_ENABLED
        uniform sampler2D BUFFER_HDR;

        #include "/lib/camera/bloom.glsl"
    #endif

    #include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #ifdef BLOOM_ENABLED
            bloomTileCount = GetBloomTileCount();
        #endif

        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
                vec2 skyLightIntensity = GetSkyLightIntensity();
                vec2 eyeBrightness = eyeBrightnessSmooth / 240.0;
                averageLuminance = GetAverageLuminance_EyeBrightness(eyeBrightness, skyLightIntensity);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                luminanceLod = textureQueryLevels(BUFFER_LUMINANCE) - 1;
                averageLuminance = GetAverageLuminance_Mipmap(luminanceLod);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_HISTOGRAM
                averageLuminance = GetAverageLuminance_Histogram();
            #else
                averageLuminance = 0.0;
            #endif

            EV100 = GetEV100(averageLuminance);
        #else
            const float EV100 = CAMERA_EXPOSURE;
        #endif

        exposure = GetExposure(EV100);
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    flat in float exposure;

    #ifdef BLOOM_ENABLED
        flat in int bloomTileCount;
    #endif

    #if DEBUG_VIEW == DEBUG_VIEW_LUMINANCE
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
    #elif DEBUG_VIEW == DEBUG_VIEW_PREVIOUS
        // HDR Previous Frame
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
                color = vec3(1.0, 0.0, 0.0) * step(texcoord.y, avgLum);
            }
            else if (gl_FragCoord.x < 16) {
                color = vec3(0.0, 1.0, 0.0) * step(texcoord.y, (EV100 + 3.0) / 10.0);

                vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
                if (abs(texcoord.y - (3.0 / 10.0)) < 2.0 * pixelSize.y)
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
            vec3 color = texelFetch(BUFFER_HDR, itex, 0).rgb * exposure;

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

            //float avgLum = GetAverageLuminance();
            //float exposure = GetExposure(avgLum);
            color = ApplyTonemap(color);

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
            int lod = texcoord.x < 0.5 ? 0 : luminanceLod-2;
            float logLum = textureLod(BUFFER_LUMINANCE, texcoord, lod).r;
            color = vec3(exp2(logLum));

            #if defined DEBUG_EXPOSURE_METERS && CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
                RenderLuminanceMeters(color, averageLuminance, EV100);
            #endif
        #elif DEBUG_VIEW == DEBUG_VIEW_PREVIOUS
            // HDR Previous Frame
            color = texture(BUFFER_HDR_PREVIOUS, texcoord).rgb;
        #else
            // None
            color = GetFinalColor();
        #endif

    /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(color, 1.0);
    }
#endif
