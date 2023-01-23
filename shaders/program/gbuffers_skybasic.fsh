#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SKYBASIC

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

flat in float exposure;
flat in vec3 sunColor;
flat in vec3 moonColor;
flat in vec3 sunTransmittanceEye;
flat in vec3 moonTransmittanceEye;

uniform sampler2D noisetex;
uniform sampler2D BUFFER_SKY_LUT;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float near;
uniform float far;
    
uniform int isEyeInWater;
uniform float rainStrength;
uniform float wetness;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform int moonPhase;

#if SHADER_PLATFORM == PLATFORM_OPTIFINE
    uniform int worldTime;
#endif

#include "/lib/sampling/noise.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/hillaire_common.glsl"
#include "/lib/celestial/position.glsl"
#include "/lib/celestial/transmittance.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/world/scattering.glsl"

#include "/lib/sky/hillaire_render.glsl"

/* RENDERTARGETS: 4,3 */
layout(location = 0) out vec3 outColor0;
layout(location = 1) out float outColor1;


void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec3 clipPos = vec3(gl_FragCoord.xy / viewSize, 1.0) * 2.0 - 1.0;
    vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));
    vec3 viewDir = normalize(viewPos);

    vec3 localViewDir = mat3(gbufferModelViewInverse) * viewDir;
    vec3 color = GetFancySkyLuminance(cameraPosition.y, localViewDir, 0);

    vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 localDir = normalize(localPos);

    if (localDir.y > 0.0) {
        float starHorizonFogF = 1.0 - abs(localDir.y);
        vec3 starF = GetStarLight(localDir);
        starF *= 1.0 - starHorizonFogF;
        color += starF * StarLumen;
    }

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        vec3 localSunDir = normalize(GetFixedSunPosition());
    #else
        vec3 localSunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    #endif

    #ifdef SUN_FANCY
        color += GetSunWithBloom(localViewDir, localSunDir) * sunTransmittanceEye * sunColor * SunLux;
    #endif

    outColor1 = log2(luminance(color) + EPSILON);
    outColor0 = clamp(color * exposure, vec3(0.0), vec3(65000));
}
