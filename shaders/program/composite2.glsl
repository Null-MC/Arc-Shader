#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_BLOOM_DOWNSCALE

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    flat out int tileCount;
    flat out float exposure;

    uniform sampler2D BUFFER_HDR;
    uniform sampler2D BUFFER_LUMINANCE;

    #include "/lib/camera/bloom.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        tileCount = GetBloomTileCount();

        float averageLuminance = 0.0;
        #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
            #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
                vec2 skyLightIntensity = GetSkyLightIntensity();
                vec2 eyeBrightness = eyeBrightnessSmooth / 240.0;
                averageLuminance = GetAverageLuminance_EyeBrightness(eyeBrightness, skyLightIntensity);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                int luminanceLod = textureQueryLevels(BUFFER_LUMINANCE) - 1;
                averageLuminance = GetAverageLuminance_Mipmap(luminanceLod);
            #elif CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_HISTOGRAM
                averageLuminance = GetAverageLuminance_Histogram();
            #else
                averageLuminance = 2.0;
            #endif

            float EV100 = GetEV100(averageLuminance);
        #else
            const float EV100 = 0.0;
        #endif

        exposure = GetExposure(EV100 - CAMERA_EXPOSURE);
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    flat in int tileCount;
    flat in float exposure;

    uniform sampler2D BUFFER_HDR;
    uniform sampler2D depthtex0;

    uniform float viewWidth;
    uniform float viewHeight;

    #include "/lib/camera/bloom.glsl"


    int GetBloomTileOuterIndex(const in int tileCount) {
        vec2 tileMin, tileMax;
        for (int i = 0; i < tileCount; i++) {
            GetBloomTileOuterBounds(i, tileMin, tileMax);

            if (texcoord.x > tileMin.x && texcoord.x <= tileMax.x
             && texcoord.y > tileMin.y && texcoord.y <= tileMax.y) return i;
        }

        return -1;
    }

    void main() {
        int tile = GetBloomTileOuterIndex(tileCount);

        vec3 final = vec3(0.0);
        if (tile >= 0) {
            vec2 viewSize = vec2(viewWidth, viewHeight);
            vec2 pixelSize = 1.0 / viewSize;

            vec2 tileMin, tileMax;
            GetBloomTileInnerBounds(tile, tileMin, tileMax);

            //vec4 clipPos = vec4(texcoord, 0.0, 1.0);

            //ivec2 itex = ivec2(texcoord * viewSize);
            //float clipDepth = texelFetch(depthtex0, itex, 0).r;
            //float depthLinear = linearizeDepth(clipDepth * 2.0 - 1.0, near, far);
            //float depthFactor = clamp(1.0 - (depthLinear - near) / far, 0.0, 1.0);
            //clipPos = clipPos * 2.0 - 1.0;

            //vec4 viewPos = gbufferProjectionInverse * clipPos;
            //viewPos.xyz /= viewPos.w;

            vec2 tileSize = tileMax - tileMin;
            vec2 tileTex = (texcoord - tileMin) / tileSize;
            //tileTex = clamp(tileTex, 0.5 * pixelSize, 1.0 - 0.5 * pixelSize);

            final = texture2DLod(BUFFER_HDR, tileTex, tile).rgb;
            //final = textureGather(BUFFER_HDR, tileTex, tile).rgb;

            // vec2 uv1 = tileTex + vec2();
            // vec2 uv2 = tileTex + vec2();
            // vec2 uv3 = tileTex + vec2();
            // vec2 uv4 = tileTex + vec2();

            // vec3 sample1 = texture2DLod(BUFFER_HDR, uv1, tile).rgb;
            // vec3 sample2 = texture2DLod(BUFFER_HDR, uv2, tile).rgb;
            // vec3 sample3 = texture2DLod(BUFFER_HDR, uv3, tile).rgb;
            // vec3 sample4 = texture2DLod(BUFFER_HDR, uv4, tile).rgb;
            
            //final *= (0.5 + 0.5 * depthFactor);

            float lum = luminance(final) * exposure;

            //lum /= clamp(exp2(5.0 + 0.2 * tile), 0.001, 1000);
            //float lum = luminance(final);

            //lum = clamp(lum / exp2(3 + 0.2 * tile), 0.0, 1.0);
            //lum = clamp(lum / (16.0 + 0.1 * tile), 0.0, 65000.0);
            lum = lum / exp2(11 + tile);
            //lum = pow(lum, 4.0);

            //lum = pow(lum, 8.0 + tile);
            final *= lum;

            final = final / (final + 1.0);
        }

    /* DRAWBUFFERS:7 */
        gl_FragData[0] = vec4(final, 1.0);
    }
#endif
