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
const bool shadowcolor1Clear = true;

const bool generateShadowMipmap = true;

const bool shadowtex0Mipmap = false;
const bool shadowtex0Nearest = false;
const bool shadowHardwareFiltering0 = true;

const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;
const bool shadowHardwareFiltering1 = true;


in vec3 gLocalPos;
in vec2 gTexcoord;
in vec2 gLmcoord;
in vec4 gColor;
flat in int gBlockId;
flat in int gEntityId;

#ifdef SSS_ENABLED
    flat in float gMaterialSSS;
#endif

#if defined RSM_ENABLED || defined WATER_FANCY
    in vec3 gViewPos;
    in mat3 gMatShadowViewTBN;
#endif

#ifdef RSM_ENABLED
    flat in mat3 gMatViewTBN;
#endif

#if SHADOW_TYPE == SHADOW_TYPE_CASCADED
    flat in vec2 gShadowTilePos;
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

#if defined WATER_ENABLED && defined WATER_FANCY
    flat in int gWaterMask;

    uniform sampler2D BUFFER_WATER_WAVES;

    uniform vec3 cameraPosition;
    uniform float frameTimeCounter;
    uniform float rainStrength;
#endif

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"

#if defined WATER_ENABLED && defined WATER_FANCY
    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"
#endif

#ifdef PHYSICS_OCEAN
    #include "/lib/physicsMod/water.glsl"
#endif

#ifdef RSM_ENABLED
    #include "/lib/lighting/fresnel.glsl"
    #include "/lib/lighting/brdf.glsl"
#endif

/* RENDERTARGETS: 0,1 */
#if defined SHADOW_COLOR || (defined SSS_ENABLED && !defined RSM_ENABLED)
    layout(location = 0) out vec4 outColor0;
#endif
#if defined RSM_ENABLED || (defined SSS_ENABLED && defined SHADOW_COLOR) || defined WATER_FANCY
    layout(location = 1) out uvec2 outColor1;
#endif


void main() {
    mat2 dFdXY = mat2(dFdx(gTexcoord), dFdy(gTexcoord));

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec2 screenCascadePos = 2.0 * (gl_FragCoord.xy / shadowMapSize - gShadowTilePos);
        if (saturate(screenCascadePos.xy) != screenCascadePos.xy) discard;
    #endif

    vec4 sampleColor;
    if (gBlockId == MATERIAL_WATER) {
        sampleColor = WATER_COLOR;
    }
    else {
        sampleColor = textureGrad(gtexture, gTexcoord, dFdXY[0], dFdXY[1]);
        sampleColor.rgb = RGBToLinear(sampleColor.rgb * gColor.rgb);
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
    #if defined RSM_ENABLED || defined WATER_FANCY
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
            vec2 normalMap = textureGrad(normals, gTexcoord, dFdXY[0], dFdXY[1]).rg;
            normal = GetLabPbr_Normal(normalMap);
        #else
            vec3 normalMap = textureGrad(normals, gTexcoord, dFdXY[0], dFdXY[1]).rgb;
            if (any(greaterThan(normalMap, vec3(0.0))))
                normal = GetOldPbr_Normal(normalMap);
        #endif
    #endif

    #if defined WATER_ENABLED && defined WATER_FANCY
        if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT && gWaterMask == 1) {
            #ifdef PHYSICS_OCEAN
                //float waviness = textureLod(physics_waviness, physics_gLocalPosition.xz / vec2(textureSize(physics_waviness, 0)), 0).r;
                normal = mat3(gl_ModelViewMatrix) * physics_waveNormal(physics_gLocalPosition.xz, physics_gLocalWaviness, physics_gameTime);
            #else
                //float windSpeed = GetWindSpeed();
                float skyLight = saturate((gLmcoord.y - (0.5/16.0)) / (15.0/16.0));
                //float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                float waveDepth = GetWaveDepth(skyLight);

                float waterScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                vec2 waterWorldPos = waterScale * (gLocalPos.xz + cameraPosition.xz);

                int octaves = WATER_OCTAVES_FAR;
                #if WATER_WAVE_TYPE != WATER_WAVE_PARALLAX
                    float viewDist = length(gViewPos);
                    float octaveDistF = saturate(viewDist / WATER_OCTAVES_DIST);
                    octaves = int(mix(WATER_OCTAVES_NEAR, WATER_OCTAVES_FAR, octaveDistF));
                #endif

                float finalDepth = GetWaves(waterWorldPos, waveDepth, octaves);
                vec3 waterPos = vec3(waterWorldPos.x, waterWorldPos.y, finalDepth);
                waterPos.z *= waveDepth * WaterWaveDepthF * WATER_NORMAL_STRENGTH;

                normal = normalize(
                    cross(
                        dFdy(waterPos),
                        dFdx(waterPos))
                    );

                #if SHADER_PLATFORM == PLATFORM_IRIS
                    //normal = -normal;
                #endif
            #endif
        }
    #endif

    float sss = 0.0;
    #ifdef SSS_ENABLED
        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            sss = gMaterialSSS;
        #else
            float specularMapB = textureGrad(specular, gTexcoord, dFdXY[0], dFdXY[1]).b;
            sss = GetLabPbr_SSS(specularMapB);
        #endif

        //#ifdef PHYSICSMOD_ENABLED
            if (gBlockId == MATERIAL_PHYSICS_SNOW) {
                sss = gMaterialSSS;
            }
        //#endif

        #if !defined SHADOW_COLOR && defined SSS_ENABLED && !defined RSM_ENABLED
            // blending SSS is probably bad, should just ignore transparent
            outColor0 = vec4(sss, 0.0, 0.0, sampleColor.a);
        #endif
    #endif

    #if defined RSM_ENABLED || defined WATER_FANCY
        #ifdef RSM_ENABLED
            vec3 albedo = mix(vec3(0.0), sampleColor.rgb, sampleColor.a);
            vec2 specularMap = textureGrad(specular, gTexcoord, dFdXY[0], dFdXY[1]).rg;

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

            vec3 viewDir = normalize(-gViewPos);
            vec3 viewNormal = gMatViewTBN * normal;
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
        
        vec3 shadowViewNormal = normal;
        #ifdef PHYSICS_OCEAN
            if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT || gWaterMask != 1)
                shadowViewNormal = gMatShadowViewTBN * normal;
        #else
            shadowViewNormal = gMatShadowViewTBN * normal;
        #endif

        shadowViewNormal = shadowViewNormal * 0.5 + 0.5;
    #else
        vec3 diffuse = vec3(0.0);
        vec3 shadowViewNormal = vec3(0.0);
    #endif

    #if defined RSM_ENABLED || (defined SHADOW_COLOR && defined SSS_ENABLED) || defined WATER_FANCY
        uvec2 data;
        data.r = packUnorm4x8(vec4(LinearToRGB(diffuse), 1.0));
        data.g = packUnorm4x8(vec4(shadowViewNormal, sss));
        outColor1 = data;
    #endif
}
