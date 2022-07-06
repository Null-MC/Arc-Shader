#extension GL_ARB_shading_language_packing : enable
#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE

varying vec2 texcoord;

#if CAMERA_EXPOSURE == 0
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

        #if CAMERA_EXPOSURE == 0
            skyLightIntensity = GetSkyLightIntensity();
        #endif
    }
#endif

#ifdef RENDER_FRAG
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
        uniform sampler2D colortex5;
    #elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
        // Bloom Tiles
        uniform sampler2D colortex7;
    #else
        uniform sampler2D colortex4;
        uniform sampler2D colortex7;

        uniform ivec2 eyeBrightnessSmooth;
        uniform float screenBrightness;
        uniform float viewWidth;
        uniform float viewHeight;

        #include "/lib/bloom.glsl"
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
            vec3 color = texture(colortex4, texcoord).rgb;

            #ifdef BLOOM_ENABLED
                int tileCount = GetBloomTileCount();

                vec3 bloom = vec3(0.0);
                for (int i = 0; i < tileCount; i++) {
                    vec2 tileMin, tileMax;
                    GetBloomTileInnerBounds(i, tileMin, tileMax);

                    vec2 tileTex = texcoord * (tileMax - tileMin) + tileMin;
                    tileTex = clamp(tileTex, tileMin, tileMax);

                    vec3 sample = textureLod(colortex7, tileTex, 0).rgb;
                    bloom += clamp(sample, 0.0, 1.0);
                }

                float lum = luminance(bloom);
                //color /= 1.0 + lum;

                color += bloom * (0.01 * BLOOM_STRENGTH);
            #endif

            #if CAMERA_EXPOSURE == 0
                vec2 eyeBrightness = eyeBrightnessSmooth / 240.0;
                eyeBrightness.y *= max(skyLightIntensity.x, skyLightIntensity.y);
                float finalBrightness = max(eyeBrightness.x, eyeBrightness.y);

                float f = min(finalBrightness * finalBrightness, 1.0);
                float exposure = mix(0.0, 1.8, f);
            #else
                const float exposure = 0.1 * CAMERA_EXPOSURE;
            #endif

            color *= exp2(exposure);
            color = ApplyTonemap(color);

            //mat4 matSaturation = GetSaturationMatrix(1.5);
            //color = mat3(matSaturation) * color;

            //color = LinearToRGB(color);
            color = TonemapLinearToRGB(color);

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
                color = texelFetch(colortex5, iuv, 0).rgb;
            #else
                const float rsm_scale = 1.0 / exp2(RSM_SCALE);
                color = textureLod(colortex5, texcoord * rsm_scale, 0).rgb;
            #endif
        #elif DEBUG_VIEW == DEBUG_VIEW_BLOOM
            // Bloom Tiles
            color = texture(colortex7, texcoord).rgb;
        #else
            // None
            color = GetFinalColor();
        #endif

    /* DRAWBUFFERS:8 */
        gl_FragData[0] = vec4(color, 1.0);
    }
#endif
