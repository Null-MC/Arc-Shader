#define RENDER_FRAG
#define RENDER_DEFERRED
//#define RENDER_DEFERRED_REFRACT

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

uniform sampler2D BUFFER_HDR;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 outColor0;


void main() {
    vec3 color = texelFetch(BUFFER_HDR, ivec2(gl_FragCoord.xy), WATER_REFRACT_QUALITY).rgb;
    outColor0 = vec4(color, 1.0);
}
