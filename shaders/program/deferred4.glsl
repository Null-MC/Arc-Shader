#extension GL_ARB_texture_query_levels : enable
#extension GL_EXT_gpu_shader4 : enable

#define RENDER_DEFERRED
#define RENDER_OPAQUE_FINAL

#ifdef RENDER_VERTEX
    out vec2 texcoord;
    flat out float exposure;
    flat out vec3 blockLightColor;

    #if CAMERA_EXPOSURE_MODE != EXPOSURE_MODE_MANUAL
        uniform sampler2D BUFFER_HDR_PREVIOUS;

        uniform float viewWidth;
        uniform float viewHeight;
    #endif

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
        uniform ivec2 eyeBrightness;
    #endif

    #ifdef SHADOW_ENABLED
        flat out vec3 sunColor;
        flat out vec3 moonColor;
        flat out vec3 skyLightColor;
    #endif

    uniform float screenBrightness;
    uniform int heldBlockLightValue;
    
    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform int moonPhase;

    #include "/lib/lighting/blackbody.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/camera/exposure.glsl"


    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #ifdef SHADOW_ENABLED
            vec2 skyLightLevels = GetSkyLightLevels();
            vec2 skyLightTemps = GetSkyLightTemp(skyLightLevels);
            sunColor = GetSunLightLux(skyLightTemps.x, skyLightLevels.x);
            moonColor = GetMoonLightLux(skyLightTemps.y, skyLightLevels.y);
            skyLightColor = GetSkyLightLuminance(skyLightLevels);
        #endif

        blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

        exposure = GetExposure();
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;
    flat in float exposure;
    flat in vec3 blockLightColor;

    #ifdef SHADOW_ENABLED
        flat in vec3 sunColor;
        flat in vec3 moonColor;
        flat in vec3 skyLightColor;
    #endif

    uniform usampler2D BUFFER_DEFERRED;
    uniform sampler2D BUFFER_HDR;
    uniform sampler2D colortex10;
    uniform sampler2D lightmap;
    uniform sampler2D depthtex0;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        uniform sampler2D BUFFER_LUMINANCE;
    #endif

    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        uniform mat4 gbufferProjection;
        uniform float far;

        uniform sampler2D BUFFER_HDR_PREVIOUS;
    #endif

    #ifdef RSM_ENABLED
        uniform sampler2D BUFFER_RSM_COLOR;
    #endif

    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelView;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float near;
    
    uniform ivec2 eyeBrightnessSmooth;
    uniform int heldBlockLightValue;

    uniform float rainStrength;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform vec3 skyColor;
    uniform int moonPhase;

    uniform vec3 fogColor;
    uniform float fogStart;
    uniform float fogEnd;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;
    #endif

    #include "/lib/sampling/linear.glsl"
    #include "/lib/lighting/scattering.glsl"
    #include "/lib/lighting/blackbody.glsl"

    #ifdef VL_ENABLED
        #ifdef SHADOW_ENABLE_HWCOMP
            uniform sampler2DShadow shadowtex1;
        #else
            uniform sampler2D shadowtex1;
        #endif

        uniform mat4 gbufferModelViewInverse;
        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;

        #if SHADOW_TYPE == 2
            #include "/lib/shadows/basic.glsl"
        #endif

        #include "/lib/lighting/volumetric.glsl"
    #endif

    #include "/lib/world/sky.glsl"
    #include "/lib/world/fog.glsl"
    #include "/lib/lighting/basic.glsl"
    #include "/lib/lighting/material.glsl"
    #include "/lib/lighting/material_reader.glsl"
    #include "/lib/lighting/hcm.glsl"
    #include "/lib/lighting/pbr.glsl"

    #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
        #include "/lib/ssr.glsl"
    #endif

    /* RENDERTARGETS: 4,6 */
    out vec3 outColor0;

    #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
        out float outColor1;
    #endif


    void main() {
        ivec2 iTex = ivec2(gl_FragCoord.xy);
        float screenDepth = texelFetch(depthtex0, iTex, 0).r;

        // SKY
        if (screenDepth == 1.0) {
            #ifdef SKY_ENABLED
                outColor0 = texelFetch(BUFFER_HDR, iTex, 0).rgb;

                #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                    outColor1 = texelFetch(BUFFER_LUMINANCE, iTex, 0).r;
                #endif
            #else
                vec3 color = RGBToLinear(fogColor) * 100.0;

                #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                    outColor1 = log2(luminance(color) + EPSILON);
                #endif

                outColor0 = clamp(color * exposure, 0.0, 65000.0);
            #endif
        }
        else {
            uvec4 deferredData = texelFetch(BUFFER_DEFERRED, iTex, 0);
            vec4 colorMap = unpackUnorm4x8(deferredData.r);
            vec4 normalMap = unpackUnorm4x8(deferredData.g);
            vec4 specularMap = unpackUnorm4x8(deferredData.b);
            vec4 lightingMap = unpackUnorm4x8(deferredData.a);

            vec3 clipPos = vec3(texcoord, screenDepth) * 2.0 - 1.0;
            vec4 viewPos = gbufferProjectionInverse * vec4(clipPos, 1.0);
            viewPos.xyz /= viewPos.w;

            PbrMaterial material;
            PopulateMaterial(material, colorMap.rgb, normalMap, specularMap);

            vec3 color = PbrLighting2(material, lightingMap.xy, lightingMap.b, lightingMap.a, viewPos.xyz).rgb;

            #if CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_MIPMAP
                outColor1 = log2(luminance(color) + EPSILON);
            #endif

            outColor0 = clamp(color * exposure, vec3(0.0), vec3(1000.0));
        }
    }
#endif
