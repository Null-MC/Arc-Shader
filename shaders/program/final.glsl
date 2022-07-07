#extension GL_ARB_shading_language_packing : enable
#extension GL_ARB_texture_query_levels : enable

#define RENDER_FINAL

varying vec2 texcoord;

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    flat varying vec2 skyLightIntensity;
#endif

#ifdef RENDER_VERTEX
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;

    #include "/lib/world/sky.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
            skyLightIntensity = GetSkyLightIntensity();
        #endif
    }
#endif

#ifdef RENDER_FRAG
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

            #include "/lib/bloom.glsl"
        #endif

        #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
            uniform sampler2D BUFFER_LUMINANCE;
        #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
            uniform ivec2 eyeBrightnessSmooth;
        #endif

        #include "/lib/tonemap.glsl"
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
            vec3 color = texelFetch(BUFFER_HDR, itex, 0).rgb;

            float averageLuminance = 0.0;
            #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                int minMip = textureQueryLevels(BUFFER_LUMINANCE);
                averageLuminance = textureLod(BUFFER_LUMINANCE, vec2(0.5), minMip).r;
                averageLuminance = exp2(averageLuminance);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
                vec2 eyeBrightness = eyeBrightnessSmooth / 240.0;
                eyeBrightness.y *= max(skyLightIntensity.x, skyLightIntensity.y);
                averageLuminance = 0.04 + 0.06 * max(eyeBrightness.x, eyeBrightness.y);
            #endif

            #ifdef BLOOM_ENABLED
                int tileCount = GetBloomTileCount();

                vec3 bloom = vec3(0.0);
                for (int i = 0; i < tileCount; i++) {
                    vec2 tileMin, tileMax;
                    GetBloomTileInnerBounds(i, tileMin, tileMax);

                    vec2 tileTex = texcoord * (tileMax - tileMin) + tileMin;
                    tileTex = clamp(tileTex, tileMin, tileMax);

                    vec3 sample = textureLod(BUFFER_BLOOM, tileTex, 0).rgb;
                    bloom += clamp(sample, 0.0, 1.0);
                }

                float lum = luminance(bloom);
                //color /= 1.0 + lum;

                color += bloom * (0.01 * BLOOM_STRENGTH);
            #endif

            #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
                float exposure = EXPOSURE_POINT / clamp(averageLuminance, EXPOSURE_LUM_MIN, EXPOSURE_LUM_MAX);
            #else
                const float exposure = 0.1 * CAMERA_EXPOSURE;
            #endif

            color = ApplyTonemap(color * exposure);

            //mat4 matSaturation = GetSaturationMatrix(1.5);
            //color = mat3(matSaturation) * color;

            return TonemapLinearToRGB(color);
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
            //int minMip = textureQueryLevels(BUFFER_LUMINANCE);
            float logLum = textureLod(BUFFER_LUMINANCE, texcoord, 0).r;
            color = vec3(exp2(logLum));
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
