#define RENDER_ENTITIES
#define RENDER_GBUFFER
#define RENDER_VERTEX

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out float geoNoL;
out vec3 localPos;
out vec3 viewPos;
out vec3 viewNormal;
out vec3 viewTangent;
flat out float tangentW;
flat out mat2 atlasBounds;
flat out int materialId;

#ifdef AF_ENABLED
    out vec4 spriteBounds;
#endif

#ifdef PARALLAX_ENABLED
    out vec2 localCoord;
    out vec3 tanViewPos;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        out vec3 tanLightPos;
    #endif
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    uniform vec3 shadowLightPosition;
#endif

uniform sampler2D gtexture;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int entityId;

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/pbr.glsl"


void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    materialId = entityId;

    localPos = gl_Vertex.xyz;
    BasicVertex(localPos);
    
    if (materialId == MATERIAL_LIGHTNING_BOLT) {
        // No PBR for lightning
    }
    else PbrVertex(viewPos);

    // PhysicsMod snow
    if (entityId == 829925) {
        materialId = MATERIAL_PHYSICS_SNOW;
    }
    
    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 viewDir = normalize(viewPos);
        ApplyShadows(localPos, viewDir);
    #endif

    #ifdef SKY_ENABLED
        sunColor = GetSunLuxColor();
        moonColor = GetMoonLuxColor();// * GetMoonPhaseLevel();
        skyLightLevels = GetSkyLightLevels();
    #endif

    blockLightColor = blackbody(BLOCKLIGHT_TEMP) * BlockLightLux;

    exposure = GetExposure();

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        vec3 shadowViewPos = (shadowModelView * (gbufferModelViewInverse * vec4(viewPos, 1.0))).xyz;

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                mat4 matShadowProjection = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                shadowPos[i] = (matShadowProjection * vec4(shadowViewPos, 1.0)).xyz * 0.5 + 0.5;
                
                vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
                shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;

                vec2 shadowProjectionSize = 2.0 / vec2(matShadowProjection[0].x, matShadowProjection[1].y);;
                shadowBias[i] = GetCascadeBias(geoNoL, shadowProjectionSize);
            }
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            shadowPos = shadowProjection * vec4(shadowViewPos, 1.0);

            #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
                shadowBias = GetShadowBias(geoNoL, distortFactor);
            #else
                shadowBias = GetShadowBias(geoNoL);
            #endif

            shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
        #endif
    #endif
}
