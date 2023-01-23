#define RENDER_VERTEX
#define RENDER_GBUFFER
#define RENDER_SKYTEXTURED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;
out vec4 glcolor;
flat out float exposure;
flat out vec3 sunColor;
flat out vec3 moonColor;
flat out vec3 sunTransmittanceEye;
flat out vec3 moonTransmittanceEye;

#if SHADER_PLATFORM == PLATFORM_IRIS
    uniform sampler3D texSunTransmittance;
#else
    uniform sampler3D colortex12;
#endif

uniform int renderStage;
uniform vec3 cameraPosition;
uniform float screenBrightness;
uniform float eyeAltitude;
uniform float wetness;

#if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    
    uniform float viewWidth;
    uniform float viewHeight;
#endif

uniform float rainStrength;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform ivec2 eyeBrightness;
    uniform int heldBlockLightValue;
#endif

uniform float nightVision;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if SHADER_PLATFORM == PLATFORM_OPTIFINE
    uniform mat4 gbufferModelView;
    uniform int worldTime;
#endif

#include "/lib/lighting/blackbody.glsl"
#include "/lib/sky/hillaire_common.glsl"
#include "/lib/celestial/position.glsl"
#include "/lib/celestial/transmittance.glsl"
#include "/lib/world/sky.glsl"
#include "/lib/camera/exposure.glsl"


void main() {
    #ifdef SUN_FANCY
        if (renderStage == MC_RENDER_STAGE_SUN) {
            gl_Position = vec4(10.0);
            return;
        }
    #endif

    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    exposure = GetExposure();
    sunColor = GetSunColor();
    moonColor = GetMoonColor();

    vec2 skyLightLevels = GetSkyLightLevels();
    float eyeElevation = GetScaledSkyHeight(eyeAltitude);
    
    #if SHADER_PLATFORM == PLATFORM_IRIS
        sunTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.x);
        moonTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.y);
    #else
        sunTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.x);
        moonTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.y);
    #endif
}
