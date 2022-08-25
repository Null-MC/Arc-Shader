#define RENDER_VERTEX
#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_PREV_FRAME

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    flat out float eyeLum;

    uniform int heldBlockLightValue;
    uniform ivec2 eyeBrightness;

    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    uniform vec3 skyColor;
    uniform vec3 fogColor;

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"

    float GetEyeBrightnessLuminance() {
        vec2 eyeBrightnessLinear = saturate2(eyeBrightness / 240.0);

        vec2 skyLightLevels = GetSkyLightLevels();
        float sunLightLux = GetSunLightLux(skyLightLevels.x);
        float moonLightLux = GetMoonLightLux(skyLightLevels.y);
        float skyLightBrightness = eyeBrightnessLinear.y * (sunLightLux + moonLightLux);

        float blockLightBrightness = eyeBrightnessLinear.x;

        #ifdef HANDLIGHT_ENABLED
            blockLightBrightness = max(blockLightBrightness, heldBlockLightValue * 0.0625);
        #endif

        blockLightBrightness = pow3(blockLightBrightness) * BlockLightLux;

        return 10.0 + 0.05 * max(blockLightBrightness, skyLightBrightness);
    }
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        eyeLum = GetEyeBrightnessLuminance();
    #endif
}
