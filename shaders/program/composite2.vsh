//#define RENDER_COMPOSITE_PREV_FRAME
#define RENDER_COMPOSITE
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    flat out float eyeLum;

    uniform sampler3D TEX_SUN_TRANSMIT;

    uniform int heldBlockLightValue;
    uniform ivec2 eyeBrightness;
    uniform float eyeAltitude;

    uniform mat4 gbufferModelView;

    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;
    uniform float wetness;

    uniform vec3 skyColor;
    uniform vec3 fogColor;

    #ifndef IS_IRIS
        uniform int worldTime;
    #endif

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"

    float GetEyeBrightnessLuminance() {
        vec2 eyeBrightnessLinear = saturate(eyeBrightness / 240.0);

        #ifdef WORLD_SKY_ENABLED
            vec2 skyLightLevels = GetSkyLightLevels();
            float eyeElevation = GetScaledSkyHeight(eyeAltitude);

            vec3 sunTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.x);
            vec3 moonTransmittanceEye = GetTransmittance(eyeElevation, skyLightLevels.y);

            float sunLightLum = luminance(sunTransmittanceEye * GetSunLuxColor());
            float moonLightLum = luminance(moonTransmittanceEye * GetMoonLuxColor()) * GetMoonPhaseLevel();
            float skyLightBrightness = eyeBrightnessLinear.y * (sunLightLum + moonLightLum);
        #endif

        float blockLightBrightness = eyeBrightnessLinear.x;

        #ifdef HANDLIGHT_ENABLED
            blockLightBrightness = max(blockLightBrightness, heldBlockLightValue * 0.0625);
        #endif

        blockLightBrightness = pow3(blockLightBrightness) * BlockLightLux;

        float brightnessFinal = 0.0;//MinWorldLux;

        #ifdef WORLD_SKY_ENABLED
            brightnessFinal += max(blockLightBrightness, skyLightBrightness);
        #else
            brightnessFinal += blockLightBrightness;
        #endif

        //return clamp(100.0 * brightnessFinal, CAMERA_LUM_MIN, CAMERA_LUM_MAX);
        eyeBrightnessLinear.x = pow3(eyeBrightnessLinear.x);

        return mix(CAMERA_LUM_MIN, 0.125 * CAMERA_LUM_MAX, maxOf(eyeBrightnessLinear));
    }
#endif


void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        eyeLum = GetEyeBrightnessLuminance();
    #endif
}
