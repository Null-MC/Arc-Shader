#extension GL_ARB_texture_query_levels : enable

#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_BLOOM_DOWNSCALE

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    flat out int tileCount;
    flat out float exposure;

    uniform sampler2D BUFFER_HDR;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;

        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    uniform float screenBrightness;
    uniform int heldBlockLightValue;

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #include "/lib/camera/bloom.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        tileCount = GetBloomTileCount();

        exposure = GetExposure();
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    flat in int tileCount;
    flat in float exposure;

    uniform sampler2D BUFFER_HDR;
    uniform sampler2D BUFFER_LUMINANCE;
    uniform sampler2D depthtex0;

    uniform float viewWidth;
    uniform float viewHeight;

    #include "/lib/camera/bloom.glsl"

    /* RENDERTARGETS: 7 */
    out vec3 outColor0;


    int GetBloomTileOuterIndex(const in int tileCount) {
        vec2 tileMin, tileMax;
        for (int i = 0; i < tileCount; i++) {
            GetBloomTileOuterBounds(i, tileMin, tileMax);

            if (texcoord.x > tileMin.x && texcoord.x <= tileMax.x
             && texcoord.y > tileMin.y && texcoord.y <= tileMax.y) return i;
        }

        return -1;
    }

    void ChangeLuminance(inout vec3 color, const in float lumNew) {
        float lumPrev = luminance(color);
        color *= (lumNew / max(lumPrev, EPSILON));
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

            #ifdef BLOOM_SMOOTH
                int t = tile+1;//max(tile - 1, 0);
                vec2 tilePixelSize = pixelSize * exp2(t);

                vec2 uv1 = tileTex + vec2(-0.5, -0.5) * tilePixelSize;
                vec2 uv2 = tileTex + vec2( 0.5, -0.5) * tilePixelSize;
                vec2 uv3 = tileTex + vec2(-0.5,  0.5) * tilePixelSize;
                vec2 uv4 = tileTex + vec2( 0.5,  0.5) * tilePixelSize;

                vec3 sample1 = textureLod(BUFFER_HDR, uv1, t).rgb;
                vec3 sample2 = textureLod(BUFFER_HDR, uv2, t).rgb;
                vec3 sample3 = textureLod(BUFFER_HDR, uv3, t).rgb;
                vec3 sample4 = textureLod(BUFFER_HDR, uv4, t).rgb;
                
                final = (sample1 + sample2 + sample3 + sample4) * 0.25;

                vec4 lumSample;
                lumSample[0] = textureLod(BUFFER_LUMINANCE, uv1, t).r;
                lumSample[1] = textureLod(BUFFER_LUMINANCE, uv2, t).r;
                lumSample[2] = textureLod(BUFFER_LUMINANCE, uv3, t).r;
                lumSample[3] = textureLod(BUFFER_LUMINANCE, uv4, t).r;
                float lum = (lumSample[0] + lumSample[1] + lumSample[2] + lumSample[3]) * 0.25;
            #else
                final = textureLod(BUFFER_HDR, tileTex, tile+1).rgb;// / exposure;
                float lum = textureLod(BUFFER_LUMINANCE, tileTex, tile+1).r;
                //final = changeLum(final, (log2(lum) - EPSILON) * exposure);
            #endif

            lum = max(exp2(lum) - EPSILON, 0.0);

            // WARN: this is a hacky fix for the NaN's that are coming through
            //final = clamp(final, vec3(0.0), vec3(10.0));

            //final *= (0.5 + 0.5 * depthFactor);

            //final /= exposure;
            //float lum = luminance(final);

            //lum /= clamp(exp2(5.0 + 0.2 * tile), 0.001, 1000);
            //float lum = luminance(final);

            //float lumNew = (lum * BLOOM_SCALE) / exp2(BLOOM_POWER + tile);
            //final *= (lumNew / max(lum, EPSILON));

            lum /= 2.0*exp2(tile);
            lum = clamp(lum * exposure, 0.0, 65554.0);
            lum = lum / (lum + 1.0);
            lum = pow2(lum);
            //lum /= 0.0004*exp2(12.0 + 0.6*tile);
            //lum = pow(lum, tile);
            //lum = max(lum - 0.01*exp2(tile), 0.0);
            ChangeLuminance(final, lum);

            //final = final / (final + 1.0);
        }

        outColor0 = clamp(final, vec3(0.0), vec3(65000.0));// * exposure * 1000.0;
    }
#endif
