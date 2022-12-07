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
    flat in float matSSS;
#endif

#if defined RSM_ENABLED || (defined WATER_FANCY)
    in vec3 viewPos;
#endif

#if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
    flat in mat3 matShadowViewTBN;
#endif

#ifdef RSM_ENABLED
    flat in mat3 matViewTBN;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat in float cascadeSizes[4];
    flat in vec2 shadowCascadePos;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform mat4 shadowModelViewInverse;
uniform int renderStage;
uniform int entityId;

#if MC_VERSION >= 11700 && SHADER_PLATFORM != PLATFORM_IRIS
   uniform float alphaTestRef;
#endif

// #if defined RSM_ENABLED || (defined SHADOW_COLOR && defined SSS_ENABLED) || (defined WATER_FANCY && defined VL_WATER_ENABLED)
//     uniform sampler2D normals;
// #endif

// #ifdef SSS_ENABLED
//     uniform sampler2D specular;
// #endif

#ifdef RSM_ENABLED
    uniform vec3 shadowLightPosition;
#endif

#if defined WATER_FANCY && !defined WORLD_NETHER
    flat in int waterMask;

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

#ifdef RSM_ENABLED
    #include "/lib/lighting/fresnel.glsl"
    #include "/lib/lighting/brdf.glsl"
#endif

/* RENDERTARGETS: 0,1 */
//#if defined SHADOW_COLOR || (defined SSS_ENABLED && !defined RSM_ENABLED)
    out vec4 outColor0;
//#endif
//#if defined RSM_ENABLED || (defined SSS_ENABLED && defined SHADOW_COLOR) || (defined WATER_FANCY && defined VL_WATER_ENABLED)
    out uvec2 outColor1;
//#endif


void main() {
    if (renderStage == MC_RENDER_STAGE_ENTITIES) {
        if (entityId == MATERIAL_LIGHTNING_BOLT) {
            discard;
            return;
        }
    }

    mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec2 screenCascadePos = 2.0 * (gl_FragCoord.xy / shadowMapSize - shadowCascadePos);
        if (saturate(screenCascadePos.xy) != screenCascadePos.xy) discard;
    #endif

    vec4 sampleColor;
    if (materialId == MATERIAL_WATER) {
        sampleColor = WATER_COLOR;
    }
    else {
        sampleColor = textureGrad(gtexture, texcoord, dFdXY[0], dFdXY[1]);
        sampleColor.rgb = RGBToLinear(sampleColor.rgb * glcolor.rgb);
    }

    #if defined SHADOW_COLOR
        vec4 lightColor = sampleColor;

        if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
            lightColor.rgb = vec3(1.0);
        }

        outColor0 = lightColor;
    #endif

    if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
        if (sampleColor.a < alphaTestRef) discard;
        sampleColor.a = 1.0;
    }

    vec3 normal = vec3(0.0, 0.0, 1.0);
    #if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
            vec2 normalMap = textureGrad(normals, texcoord, dFdXY[0], dFdXY[1]).rg;
            normal = GetLabPbr_Normal(normalMap);
        #else
            vec3 normalMap = textureGrad(normals, texcoord, dFdXY[0], dFdXY[1]).rgb;
            if (any(greaterThan(normalMap, vec3(0.0))))
                normal = GetOldPbr_Normal(normalMap);
        #endif
    #endif

    #if defined WATER_FANCY && !defined WORLD_NETHER && !defined WORLD_END
        if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT && waterMask == 1) {
            //float windSpeed = GetWindSpeed();
            float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
            //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
            float waveDepth = GetWaveDepth(skyLight);

            float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
            vec2 waterWorldPos = waterScale * (localPos.xz + cameraPosition.xz);

            int octaves = WATER_OCTAVES_FAR;
            #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                float viewDist = length(viewPos);
                octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, saturate(viewDist / 200.0)));
            #endif

            float finalDepth = GetWaves(waterWorldPos, waveDepth, octaves);
            vec3 waterPos = vec3(waterWorldPos.x, waterWorldPos.y, finalDepth);
            waterPos.z *= waveDepth * WATER_WAVE_DEPTH * WATER_NORMAL_STRENGTH * 2.0;

            normal = normalize(
                cross(
                    dFdy(waterPos),
                    dFdx(waterPos))
                );
        }
    #endif

    float sss = 0.0;
    #ifdef SSS_ENABLED
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            sss = matSSS;
        #else
            float specularMapB = textureGrad(specular, texcoord, dFdXY[0], dFdXY[1]).b;
            sss = GetLabPbr_SSS(specularMapB);
        #endif

        //#ifdef PHYSICSMOD_ENABLED
            if (materialId == MATERIAL_PHYSICS_SNOW) {
                sss = matSSS;
            }
        //#endif

        #ifndef SHADOW_COLOR
            // blending SSS is probably bad, should just ignore transparent
            outColor0 = vec4(sss, 0.0, 0.0, sampleColor.a);
        #endif
    #endif

    #if defined RSM_ENABLED || (defined WATER_FANCY && defined VL_WATER_ENABLED)
        #ifdef RSM_ENABLED
            vec3 albedo = mix(vec3(0.0), sampleColor.rgb, sampleColor.a);
            vec2 specularMap = textureGrad(specular, texcoord, dFdXY[0], dFdXY[1]).rg;

            #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
                float roughL = pow2(specularMap.r);
                float f0 = GetLabPbr_F0(specularMap.g);
                int hcm = GetLabPbr_HCM(specularMap.g);
            #elif MATERIAL_FORMAT == MATERIAL_FORMAT_OLDPBR
                float roughL = pow2(specularMap.r);
                float f0 = specularMap.g;
                int hcm = -1;
            #else
                float roughL = 1.0; //pow2(matRough);
                float f0 = 0.04; //specularMap.g;
                int hcm = -1;
            #endif

            vec3 viewDir = normalize(-viewPos);
            vec3 viewNormal = matViewTBN * normal;
            vec3 viewLightDir = normalize(shadowLightPosition);
            vec3 halfDir = normalize(viewLightDir + viewDir);

            float NoVm = max(dot(viewNormal, viewDir), 0.0);
            float LoHm = max(dot(viewLightDir, halfDir), 0.0);
            float NoLm = max(dot(viewNormal, viewLightDir), 0.0);

            // TODO: diffuse lighting
            vec3 sunF = GetFresnel(albedo, f0, hcm, LoHm, roughL);
            vec3 diffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL) * max(1.0 - sunF, 0.0);
        #else
            vec3 diffuse = vec3(0.0);
        #endif
        
        vec3 shadowViewNormal = (matShadowViewTBN * normal) * 0.5 + 0.5;
    #else
        vec3 diffuse = vec3(0.0);
        vec3 shadowViewNormal = vec3(0.0);
    #endif

    #if defined RSM_ENABLED || (defined SHADOW_COLOR && defined SSS_ENABLED) || (defined WATER_FANCY && defined VL_WATER_ENABLED)
        uvec2 data;
        data.r = packUnorm4x8(vec4(LinearToRGB(diffuse), 1.0));
        data.g = packUnorm4x8(vec4(shadowViewNormal, sss));
        outColor1 = data;
    #endif
}
