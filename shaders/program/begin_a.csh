#define RENDER_BEGIN_SCENE
#define RENDER_BEGIN
#define RENDER_COMPUTE

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef IRIS_FEATURE_SSBO
    uniform vec3 cameraPosition;
    uniform float viewWidth;
    uniform float viewHeight;

    uniform float nightVision;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    #if MC_VERSION >= 11900
        uniform float darknessFactor;
    #endif

    #if defined SKY_ENABLED || defined LIGHT_COLOR_ENABLED
        uniform sampler3D texSunTransmittance;

        uniform mat4 gbufferModelView;
        uniform float eyeAltitude;
        uniform float rainStrength;
        uniform vec3 upPosition;
        uniform int worldTime;

        #if (defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE) || defined LIGHT_COLOR_ENABLED
            uniform mat4 shadowModelView;
            uniform float far;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                uniform mat4 gbufferPreviousModelView;
                uniform mat4 gbufferPreviousProjection;
                uniform mat4 gbufferProjection;
                uniform float near;
            #endif
        #endif
    #endif

    #include "/lib/ssbo/scene.glsl"
    #include "/lib/ssbo/lighting.glsl"

    #include "/lib/matrix.glsl"
    #include "/lib/lighting/blackbody.glsl"

    #ifdef SKY_ENABLED
        #include "/lib/sky/hillaire_common.glsl"
        #include "/lib/celestial/position.glsl"
        #include "/lib/celestial/transmittance.glsl"
        #include "/lib/world/sky.glsl"
        
        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #include "/lib/shadows/common.glsl"

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                #include "/lib/shadows/csm.glsl"
            #endif
        #endif
    #endif

    #if defined LIGHT_COLOR_ENABLED && (!defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE)
        #ifndef SKY_ENABLED
            #include "/lib/celestial/position.glsl"
        #endif
        
        #include "/lib/shadows/common.glsl"
    #endif

    #include "/lib/camera/exposure.glsl"
#endif


void main() {
    #ifdef IRIS_FEATURE_SSBO
        SceneLightCount = 0;

        sceneExposure = GetExposure();

        blockLightColor = blackbody(BLOCKLIGHT_TEMP);

        #ifdef SKY_ENABLED
            skyLightLevels = GetSkyLightLevels();
            float eyeElevation = GetScaledSkyHeight(eyeAltitude);

            skySunColor = GetSunColor();

            #ifdef IS_IRIS
                sunTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.x);
            #else
                sunTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.x);
            #endif

            #ifdef WORLD_MOON_ENABLED
                skyMoonColor = GetMoonColor();

                #ifdef IS_IRIS
                    moonTransmittanceEye = GetTransmittance(texSunTransmittance, eyeElevation, skyLightLevels.y);
                #else
                    moonTransmittanceEye = GetTransmittance(colortex12, eyeElevation, skyLightLevels.y);
                #endif
            #endif
        #endif

        #if (defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE) || defined LIGHT_COLOR_ENABLED
            shadowModelViewEx = BuildShadowViewMatrix();

            #if SHADOW_TYPE != SHADOW_TYPE_CASCADED
                shadowProjectionEx = BuildShadowProjectionMatrix();
            #endif
        #endif

        #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
            cascadeSize[0] = GetCascadeDistance(0);
            cascadeSize[1] = GetCascadeDistance(1);
            cascadeSize[2] = GetCascadeDistance(2);
            cascadeSize[3] = GetCascadeDistance(3);

            for (int i = 0; i < 4; i++) {
                shadowProjectionPos[i] = GetShadowCascadeClipPos(i);
                cascadeProjection[i] = GetShadowCascadeProjectionMatrix(i, cascadeViewMin[i], cascadeViewMax[i]);

                shadowProjectionSize[i] = 2.0 / vec2(
                    cascadeProjection[i][0].x,
                    cascadeProjection[i][1].y);
            }
        #endif
    #endif

    barrier();
}
