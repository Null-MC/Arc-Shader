#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_BLOOM_DOWNSCALE

varying vec2 texcoord;

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D depthtex0;
    uniform sampler2D colortex4;

    uniform float viewWidth;
    uniform float viewHeight;
    uniform float near;
    uniform float far;

    #include "/lib/depth.glsl"
    #include "/lib/bloom.glsl"


    void main() {
        float tileMin, tileMax;
        int tile = GetBloomTileIndex(tileMin, tileMax);

        vec3 final = vec3(0.0);

        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec2 pixelSize = 1.0 / viewSize;

        if (tile >= 0) {
            //vec4 clipPos = vec4(texcoord, 0.0, 1.0);

            ivec2 itex = ivec2(texcoord * viewSize);
            float clipDepth = texelFetch(depthtex0, itex, 0).r;
            float depthLinear = linearizeDepth(clipDepth * 2.0 - 1.0, near, far);
            float depthFactor = clamp(1.0 - (depthLinear - near) / far, 0.0, 1.0);
            //clipPos = clipPos * 2.0 - 1.0;

            //vec4 viewPos = gbufferProjectionInverse * clipPos;
            //viewPos.xyz /= viewPos.w;

            float tileSize = tileMax - tileMin;
            vec2 tileTex = texcoord - tileMin;
            tileTex /= tileSize;

            final = texture2DLod(colortex4, tileTex, tile).rgb;// * depthFactor;

            float lum = luminance(final) / exp2(5.0 + 0.2 * tile);
            final *= clamp(lum, 0.0, 1.0);
            //final = vec3(lum);

            //final /= exp2(5.0 + 0.5 * tile);

            //final *= exp2(tile);
        }

    /* DRAWBUFFERS:7 */
        gl_FragData[0] = vec4(final, 1.0);
    }
#endif
