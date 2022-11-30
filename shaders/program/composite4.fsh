#define RENDER_FRAG
#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_DOF

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform sampler2D depthtex0;
uniform sampler2D BUFFER_HDR;

uniform float centerDepthSmooth;
//uniform int isEyeInWater;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
    uniform sampler2D BUFFER_LUMINANCE;
#endif

#include "/lib/depth.glsl"

/* RENDERTARGETS: 4 */
out vec3 outColor0;


// https://www.shadertoy.com/view/lstBDl

// Smaller = nicer blur, larger = faster
#define RAD_SCALE 1.0

#define GOLDEN_ANGLE 2.39996323
#define MAX_BLUR_SIZE 10.0

float getBlurSize(const in float depth, const in float focusPoint, const in float focusScale) {
    float coc = rcp(focusPoint) - rcp(depth);
    return saturate(abs(coc) * focusScale) * MAX_BLUR_SIZE;
}

void main() {
    float focusPoint = linearizeDepthFast(centerDepthSmooth, near, far);

    // TODO: make dynamic based on focus distance
    float focusScale = 3.0; //clamp(0.1 * focusPoint, 1.0, 20.0); //4.0;
    
    vec3 color = textureLod(BUFFER_HDR, texcoord, 0).rgb;
    float centerDepth = textureLod(depthtex0, texcoord, 0).r;
    centerDepth = linearizeDepthFast(centerDepth, near, far);

    float centerSize = getBlurSize(centerDepth, focusPoint, focusScale);
    
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 texelSize = rcp(viewSize);
    float radius = RAD_SCALE;
    float tot = 1.0;

    for (float ang = 0.0; radius < MAX_BLUR_SIZE; ang += GOLDEN_ANGLE) {
        vec2 tc = texcoord + vec2(cos(ang), sin(ang)) * texelSize * radius;
        
        vec3 sampleColor = textureLod(BUFFER_HDR, tc, 0).rgb;
        float sampleDepth = textureLod(depthtex0, tc, 0).r;
        sampleDepth = linearizeDepthFast(sampleDepth, near, far);

        float sampleSize = getBlurSize(sampleDepth, focusPoint, focusScale);
        
        if (sampleDepth > centerDepth)
            sampleSize = clamp(sampleSize, 0.0, centerSize*2.0);

        float m = smoothstep(radius-0.5, radius+0.5, sampleSize);
        color += mix(color / tot, sampleColor, m);
        radius += RAD_SCALE / radius;

        tot += 1.0;
    }
    
    color /= tot;

    outColor0 = color;
}
