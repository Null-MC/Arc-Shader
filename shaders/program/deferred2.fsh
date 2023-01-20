#define RENDER_FRAG
#define RENDER_DEFERRED
#define RENDER_RSM

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;
flat in float exposure;

uniform usampler2D BUFFER_DEFERRED;
uniform usampler2D shadowcolor1;
uniform sampler2D depthtex0;

//#if defined SHADOW_ENABLE_HWCOMP && !defined IRIS_FEATURE_SEPARATE_HW_SAMPLERS
//#ifndef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
    uniform sampler2D shadowtex0;
//#else
//    uniform sampler2D shadowtex1;
//#endif

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;

#include "/lib/lighting/light_data.glsl"
#include "/lib/sampling/noise.glsl"

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    #include "/lib/shadows/csm.glsl"
#elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
    #include "/lib/shadows/basic.glsl"
#endif

#include "/lib/rsm.glsl"

/* RENDERTARGETS: 8,9 */
layout(location = 0) out vec3 outColor0;
layout(location = 1) out float outColor1;


void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 itexFull = ivec2(texcoord * viewSize);

    float clipDepth = texelFetch(depthtex0, itexFull, 0).r;
    vec3 color = vec3(0.0);

    if (clipDepth < 1.0) {
        uvec2 deferredNormalLightingData = texelFetch(BUFFER_DEFERRED, itexFull, 0).ga;

        vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;
        vec3 localPos = unproject(gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clipPos, 1.0)));
        vec3 shadowViewPos = (shadowModelView * vec4(localPos, 1.0)).xyz;

        vec3 normalMap = unpackUnorm4x8(deferredNormalLightingData.r).xyz;
        vec3 viewNormal = normalize(normalMap * 2.0 - 1.0);

        vec3 shadowViewNormal = mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * viewNormal);
        //color = shadowViewNormal * 0.5 + 0.5;

        #ifdef LIGHTLEAK_FIX
            float lightingMap = unpackUnorm4x8(deferredNormalLightingData.g).g;
            if (lightingMap >= 1.0 / 16.0) {
        #endif
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                color = GetIndirectLighting_RSM(cascadeProjection, shadowViewPos, shadowViewNormal);
            #else
                color = GetIndirectLighting_RSM(shadowViewPos, shadowViewNormal);
            #endif
        #ifdef LIGHTLEAK_FIX
            }
        #endif

        color = clamp(color, vec3(0.0), vec3(65000.0));
    }

    outColor0 = color;
    outColor1 = clipDepth;
}
