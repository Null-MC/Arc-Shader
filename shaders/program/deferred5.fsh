#define RENDER_FRAG
#define RENDER_DEFERRED
#define RENDER_AO_BLUR

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform sampler2D BUFFER_AO;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

#include "/lib/depth.glsl"
#include "/lib/sampling/bilateral_gaussian.glsl"

/* RENDERTARGETS: 3 */
out float outColor0;


void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 itexFull = ivec2(texcoord * viewSize);

    float clipDepth = texelFetch(depthtex0, itexFull, 0).r;
    float occlusion = 1.0;

    if (clipDepth < 1.0) {
        float linearDepth = linearizeDepthFast(clipDepth, near, far);
        occlusion = BilateralGaussianDepthBlur_9x(BUFFER_AO, 0.5 * viewSize, depthtex0, viewSize, linearDepth, 0.9);
    }

    outColor0 = saturate(occlusion);
}
