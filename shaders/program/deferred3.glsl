#define RENDER_DEFERRED
#define RENDER_RSM_BLUR

#if defined RENDER_VERTEX
    out vec2 texcoord;
    

	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	}
#endif

#if defined RENDER_FRAG
    in vec2 texcoord;

    uniform sampler2D BUFFER_RSM_COLOR;
    uniform sampler2D BUFFER_RSM_DEPTH;

    uniform mat4 gbufferProjectionInverse;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float near;
    uniform float far;

    #include "/lib/depth.glsl"
    #include "/lib/sampling/bilateral_gaussian.glsl"

    /* RENDERTARGETS: 8 */
    out vec3 outColor0;


	void main() {
        const float rsmScale = rcp(exp2(RSM_SCALE));
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec2 rsmTexSize = rsmScale * viewSize;

        ivec2 itex = ivec2(texcoord * rsmTexSize);
        float clipDepth = texelFetch(BUFFER_RSM_DEPTH, itex, 0).r;
        vec3 color = vec3(0.0);

        if (clipDepth < 1.0) {
            float linearDepth = linearizeDepthFast(clipDepth, near, far);
            color = BilateralGaussianDepthBlurRGB_5x(BUFFER_RSM_COLOR, rsmTexSize, BUFFER_RSM_DEPTH, rsmTexSize, linearDepth, 2.0);
        }

        outColor0 = color;
	}
#endif
