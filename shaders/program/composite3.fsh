#define RENDER_COMPOSITE_BLOOM_BLUR_H
#define RENDER_COMPOSITE
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform sampler2D BUFFER_HDR_OPAQUE;

uniform float viewWidth;
uniform float viewHeight;

#if WATER_CAMERA_BLUR == 2
    #include "/lib/sampling/gaussian_17.glsl"
#else
    #include "/lib/sampling/gaussian_7.glsl"
#endif

const vec2 direction = vec2(1.0, 0.0);

/* RENDERTARGETS: 4 */
layout(location = 0) out vec3 outColor0;


void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);

    #if WATER_CAMERA_BLUR == 2
        vec3 color = GaussianBlur23(BUFFER_HDR_OPAQUE, texcoord, direction * pixelSize);
    #else
        vec3 color = GaussianBlur13(BUFFER_HDR_OPAQUE, texcoord, direction * pixelSize * 2.0);
    #endif

    outColor0 = color;
}
