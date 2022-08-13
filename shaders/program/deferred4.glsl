#define RENDER_DEFERRED
#define RENDER_AO

#if defined RENDER_VERTEX
    out vec2 texcoord;
    

	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	}
#endif

#if defined RENDER_FRAG
    in vec2 texcoord;

    uniform sampler2D BUFFER_AO;
    uniform sampler2D depthtex0;

    uniform mat4 gbufferProjectionInverse;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float near;
    uniform float far;

    #include "/lib/depth.glsl"
    //#include "/lib/ssao.glsl"

    /* RENDERTARGETS: 3 */
    out float outColor0;


    float Gaussian(const in float sigma, const in float x) {
        return exp(-pow2(x) / (2.0 * pow2(sigma)));
    }

	void main() {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        ivec2 itexFull = ivec2(texcoord * viewSize);

        float clipDepth = texelFetch(depthtex0, itexFull, 0).r;
        float occlusion = 1.0;

        if (clipDepth < 1.0) {
            vec2 pixelSize = rcp(0.5 * viewSize);
            //g_pixelSize = 1.0 / iChannelResolution[0].xy;
            //g_pixelSizeGuide = 1.0 / iChannelResolution[0].xy;

            //g_sigmaV = M.z > 0.0
            //    ? 0.03 * pow(clamp(M.y / R.y, 0., 1.), 2.0)
            //    : 0.03 * smoothstep(0.3, -0.3, cos(iTime));
            float g_sigmaV = 0.03 * pow2(0.9) + 0.001;

            //float sigmaT = 2.0;
            float g_sigmaX = 3.0;
            float g_sigmaY = 3.0;
            //float g_sigmaV = 1.0;

            //vec2 g_pixelSize = vec2(0.001);
            //vec2 g_pixelSizeGuide = vec2(0.001);

            const float c_halfSamplesX = 4.0;
            const float c_halfSamplesY = 4.0;

            float total = 0.0;
            float ret = 0.0;

            //vec2 pivot = texture(iChannel0, uv).rg;
            float linearDepth = linearizeDepthFast(clipDepth, near, far);
            
            for (float iy = -c_halfSamplesY; iy <= c_halfSamplesY; iy++) {
                float fy = Gaussian(g_sigmaY, iy);
                float offsety = iy * pixelSize.y;

                for (float ix = -c_halfSamplesX; ix <= c_halfSamplesX; ix++) {
                    float fx = Gaussian(g_sigmaX, ix);
                    float offsetx = ix * pixelSize.x;
                    
                    //vec2 value = textureLod(iChannel0, uv + vec2(offsetx, offsety)).rg;
                    vec2 sampleTex = texcoord + vec2(offsetx, offsety);
                    ivec2 sampleITex = ivec2(sampleTex * viewSize * 0.5);
                    ivec2 sampleITexFull = ivec2(sampleTex * viewSize);

                    float sampleOcclusion = texelFetch(BUFFER_AO, sampleITex, 0).r;
                    float sampleDepth = texelFetch(depthtex0, sampleITexFull, 0).r;
                    float sampleLinearDepth = linearizeDepthFast(sampleDepth, near, far);
                                
                    float fv = Gaussian(g_sigmaV, abs(sampleLinearDepth - linearDepth));
                    
                    total += fx*fy*fv;
                    ret += fx*fy*fv * sampleOcclusion;
                }
            }
            
            occlusion = ret / total;
        }

        outColor0 = occlusion;
	}
#endif
