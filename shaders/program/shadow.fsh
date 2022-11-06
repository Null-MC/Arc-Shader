#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_SHADOW

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

/*
const int shadowcolor0Format = RGBA8;
const int shadowcolor1Format = RG32UI;
*/

const bool shadowcolor0Nearest = false;
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
const bool shadowcolor0Clear = true;

const bool shadowcolor1Nearest = true;
const bool shadowcolor1Clear = false;

const bool generateShadowMipmap = true;

const bool shadowtex0Mipmap = false;
const bool shadowtex0Nearest = false;
const bool shadowHardwareFiltering0 = true;

const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;
const bool shadowHardwareFiltering1 = true;


in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 localPos;
flat in int materialId;

#ifdef SSS_ENABLED
    //flat in float matSmooth;
    flat in float matSSS;
    //flat in float matF0;
    //flat in float matEmissive;
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    in vec3 viewPos;
    flat in mat3 matViewTBN;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat in float cascadeSizes[4];
    flat in vec2 shadowCascadePos;
#endif

uniform sampler2D gtexture;

uniform mat4 shadowModelViewInverse;
uniform int renderStage;

#if MC_VERSION >= 11700 && defined IS_OPTIFINE
   uniform float alphaTestRef;
#endif

#if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_ENABLED)
    uniform sampler2D normals;
#endif

#ifdef SSS_ENABLED
    uniform sampler2D specular;
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    uniform sampler2D BUFFER_WATER_WAVES;

    uniform vec3 cameraPosition;
    uniform float frameTimeCounter;
    uniform float rainStrength;
#endif

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"

#if defined WATER_FANCY && !defined WORLD_NETHER && !defined WORLD_END
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"
#endif

/* RENDERTARGETS: 0,1 */
#if defined SHADOW_COLOR || defined SSS_ENABLED
    out vec4 outColor0;
#endif
#if defined RSM_ENABLED || (defined SSS_ENABLED && defined SHADOW_COLOR) || (defined WATER_FANCY && defined VL_ENABLED)
    out uvec2 outColor1;
#endif


void main() {
    mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec2 screenCascadePos = 2.0 * (gl_FragCoord.xy / shadowMapSize - shadowCascadePos);
        if (saturate(screenCascadePos.xy) != screenCascadePos.xy) discard;

        //if (screenCascadePos.x < 0 || screenCascadePos.x >= 0.5
        // || screenCascadePos.y < 0 || screenCascadePos.y >= 0.5) discard;
    #endif

    vec4 sampleColor;
    if (materialId == 100 || materialId == 101) {
        sampleColor = WATER_COLOR;
    }
    else {
        sampleColor = textureGrad(gtexture, texcoord, dFdXY[0], dFdXY[1]);
        sampleColor.rgb = RGBToLinear(sampleColor.rgb * glcolor.rgb);
    }

    #if defined SHADOW_COLOR //|| defined RSM_ENABLED
        vec4 lightColor = sampleColor;

        if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
            lightColor.rgb = vec3(1.0);
        }
        else {
            lightColor.rgb = mix(vec3(1.0), lightColor.rgb, sqrt(max(lightColor.a, EPSILON)));
            lightColor.rgb = mix(lightColor.rgb, vec3(0.0), pow2(lightColor.a));
        }

        lightColor.rgb = LinearToRGB(lightColor.rgb);
        outColor0 = lightColor;
    #endif

    if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
        if (sampleColor.a < alphaTestRef) discard;
        sampleColor.a = 1.0;
    }

    vec3 viewNormal = vec3(0.0);
    #if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_ENABLED)
        vec2 normalMap = textureGrad(normals, texcoord, dFdXY[0], dFdXY[1]).rg;
        viewNormal = RestoreNormalZ(normalMap);

        //sampleColor.rgb *= max(dot(viewNormal, vec3(0.0, 0.0, 1.0)), 0.0);
    #endif

    #if defined WATER_FANCY && !defined WORLD_NETHER && !defined WORLD_END
        if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT && materialId == 100) {
            float windSpeed = GetWindSpeed();
            float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
             float waveSpeed = GetWaveSpeed(windSpeed, skyLight);

            float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
            vec2 waterWorldPos = waterScale * (localPos.xz + cameraPosition.xz);

            int octaves = WATER_OCTAVES_FAR;
            #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                float viewDist = length(viewPos);
                octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, saturate(viewDist / 200.0)));
            #endif

            float waveDepth = GetWaveDepth(skyLight);

            float finalDepth = GetWaves(waterWorldPos, waveSpeed, octaves) * waveDepth * WATER_NORMAL_STRENGTH;
            vec3 waterPos = vec3(waterWorldPos.x, waterWorldPos.y, finalDepth);

            viewNormal = -normalize(
                cross(
                    dFdx(waterPos),
                    dFdy(waterPos))
                );
        }
    #endif

    #if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_ENABLED)
        viewNormal = matViewTBN * viewNormal;
    #endif

    float sss = 0.0;
    #ifdef SSS_ENABLED
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            sss = matSSS;
        #else
            float specularMapB = textureGrad(specular, texcoord, dFdXY[0], dFdXY[1]).b;
            sss = GetLabPbr_SSS(specularMapB);
        #endif

        #ifdef PHYSICSMOD_ENABLED
            if (materialId == 102) {
                sss = matSSS;
            }
        #endif

        #ifndef SHADOW_COLOR
            // blending SSS is probably bad, should just ignore transparent
            outColor0 = vec4(sss, 0.0, 0.0, sampleColor.a);
        #endif
    #endif

    #if defined RSM_ENABLED || (defined SHADOW_COLOR && defined SSS_ENABLED) || (defined WATER_FANCY && defined VL_ENABLED)
        vec3 rsmColor = mix(vec3(0.0), sampleColor.rgb, sampleColor.a);
        rsmColor = LinearToRGB(rsmColor);

        uvec2 data;
        data.r = packUnorm4x8(vec4(rsmColor, 1.0));
        data.g = packUnorm4x8(vec4(viewNormal * 0.5 + 0.5, sss));
        outColor1 = data;
    #endif
}
