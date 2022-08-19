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
const bool shadowtex0Nearest = true;
const bool shadowHardwareFiltering0 = false;

const bool shadowtex1Mipmap = false;
const bool shadowtex1Nearest = false;
const bool shadowHardwareFiltering1 = true;


in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT && defined SSS_ENABLED
    flat in float matSmooth;
    flat in float matSSS;
    flat in float matF0;
    flat in float matEmissive;
#endif

#ifdef SSS_ENABLED
    in vec3 viewPosTan;
#endif

#if defined RSM_ENABLED
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

#ifdef RSM_ENABLED
    uniform sampler2D normals;
#endif

#if defined SSS_ENABLED // || defined RSM_ENABLED
    uniform sampler2D specular;
#endif

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"

/* RENDERTARGETS: 0,1 */
#if defined RSM_ENABLED || defined SHADOW_COLOR
    out vec4 outColor0;
#endif
#if defined RSM_ENABLED || defined SSS_ENABLED
    out uvec2 outColor1;
#endif


void main() {
    mat2 dFdXY = mat2(dFdx(texcoord), dFdy(texcoord));

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec2 screenCascadePos = gl_FragCoord.xy / shadowMapSize - shadowCascadePos;
        if (screenCascadePos.x < 0 || screenCascadePos.x >= 0.5
         || screenCascadePos.y < 0 || screenCascadePos.y >= 0.5) discard;
    #endif

    vec4 sampleColor = vec4(0.0);

    #if defined RSM_ENABLED || defined SHADOW_COLOR
        sampleColor = textureGrad(gtexture, texcoord, dFdXY[0], dFdXY[1]);
        sampleColor.rgb = RGBToLinear(sampleColor.rgb * glcolor.rgb);

        vec4 lightColor = sampleColor;
        if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
            lightColor.rgb = vec3(1.0);
        }
        else {
            lightColor.rgb = mix(vec3(1.0), lightColor.rgb, sqrt(lightColor.a));
            lightColor.rgb = mix(lightColor.rgb, vec3(0.0), pow2(lightColor.a));
        }

        lightColor.rgb = LinearToRGB(lightColor.rgb);
        outColor0 = lightColor;
    #else
        sampleColor.a = textureGrad(gtexture, texcoord, dFdXY[0], dFdXY[1]).a;
        //sampleColor.a *= glcolor.a;
    #endif

    if (renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
        if (sampleColor.a < alphaTestRef) discard;
        sampleColor.a = 1.0;
    }

    vec3 viewNormal = vec3(0.0);
    #if defined RSM_ENABLED
        vec2 normalMap = textureGrad(normals, texcoord, dFdXY[0], dFdXY[1]).rg;
        viewNormal = matViewTBN * RestoreNormalZ(normalMap);

        sampleColor.rgb *= max(dot(viewNormal, vec3(0.0, 0.0, 1.0)), 0.0);
    #endif

    float sss = 0.0;
    #ifdef SSS_ENABLED
        //vec3 viewDirT = normalize(viewPosTan);

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            sss = matSSS;// * abs(viewDirT.z);
        #else
            float specularMapB = textureGrad(specular, texcoord, dFdXY[0], dFdXY[1]).b;
            sss = GetLabPbr_SSS(specularMapB);// * abs(viewDirT.z);
        #endif
    #endif

    #if defined RSM_ENABLED || defined SSS_ENABLED
        vec3 rsmColor = mix(vec3(0.0), sampleColor.rgb, sampleColor.a);
        rsmColor = LinearToRGB(rsmColor);

        uvec2 data;
        data.r = packUnorm4x8(vec4(rsmColor, 1.0));
        data.g = packUnorm4x8(vec4(viewNormal * 0.5 + 0.5, sss));
        outColor1 = data;
    #endif
}
