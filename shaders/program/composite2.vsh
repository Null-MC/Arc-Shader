#define RENDER_VERTEX
#define RENDER_COMPOSITE
//#define RENDER_COMPOSITE_PREV_FRAME

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

out vec2 texcoord;

#if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    flat out float eyeLum;

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
    #else
        uniform sampler3D colortex0;
    #endif

    uniform int heldBlockLightValue;
    uniform ivec2 eyeBrightness;
    uniform float eyeAltitude;

    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;
    uniform float wetness;

    uniform vec3 skyColor;
    uniform vec3 fogColor;

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/sky/celestial_position.glsl"
    #include "/lib/sky/celestial_color.glsl"
    #include "/lib/world/sky.glsl"

    float GetEyeBrightnessLuminance() {
        vec2 eyeBrightnessLinear = saturate(eyeBrightness / 240.0);

        #ifdef SKY_ENABLED
            vec2 skyLightLevels = GetSkyLightLevels();

            #if SHADER_PLATFORM == PLATFORM_IRIS
                vec3 sunTransmittanceEye = GetSunTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.x);
                vec3 moonTransmittanceEye = GetMoonTransmittance(texSunTransmittance, eyeAltitude, skyLightLevels.y);
            #else
                vec3 sunTransmittanceEye = GetSunTransmittance(colortex0, eyeAltitude, skyLightLevels.x);
                vec3 moonTransmittanceEye = GetMoonTransmittance(colortex0, eyeAltitude, skyLightLevels.y);
            #endif

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

        #ifdef SKY_ENABLED
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
