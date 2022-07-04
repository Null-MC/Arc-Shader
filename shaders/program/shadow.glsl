#define RENDER_GBUFFER
#define RENDER_SHADOW

/*
const int shadowtex0Format = R32F;
const int shadowtex1Format = R32F;
const int shadowcolor0Format = RG32UI;
const bool shadowcolor0Nearest = true;

shadowtex0Nearest = false;
shadowtex1Nearest = false;
*/

const float shadowDistanceRenderMul = 1.0;


varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#ifdef SSS_ENABLED
    varying vec3 viewPosTan;
#endif

#if defined RSM_ENABLED
    flat varying mat3 matViewTBN;
#endif

#if SHADOW_TYPE == 3
    flat varying float cascadeSizes[4];
    flat varying vec2 shadowCascadePos;
#endif

#ifdef RENDER_VERTEX
    in vec4 mc_Entity;
    in vec3 vaPosition;
    in vec3 at_midBlock;
    in vec4 at_tangent;

    uniform mat4 shadowModelViewInverse;
    uniform vec3 cameraPosition;
    
    #ifdef ANIM_USE_WORLDTIME
        uniform int worldTime;
    #else
        uniform float frameTimeCounter;
    #endif

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform vec3 chunkOffset;
    #else
        uniform mat4 gbufferModelViewInverse;
    #endif

    #include "/lib/world/waving.glsl"

    #if SHADOW_TYPE == 3
        uniform int entityId;
        uniform float near;
        uniform float far;

        #ifdef IS_OPTIFINE
            // NOTE: We are using the previous gbuffer matrices cause the current ones don't work in shadow pass
            uniform mat4 gbufferPreviousModelView;
            uniform mat4 gbufferPreviousProjection;
        #else
            uniform mat4 gbufferModelView;
            uniform mat4 gbufferProjection;
        #endif

        #include "/lib/shadows/csm.glsl"
    #elif SHADOW_TYPE != 0
        #include "/lib/shadows/basic.glsl"
    #endif


    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;

        #ifdef SHADOW_EXCLUDE_ENTITIES
            if (mc_Entity.x == 0.0) {
                gl_Position = vec4(10.0);

                #if SHADOW_TYPE == 3
                    shadowCascadePos = vec2(10.0);
                #endif

                return;
            }
        #endif

        #ifdef SHADOW_EXCLUDE_FOLIAGE
            if (mc_Entity.x >= 10000.0 && mc_Entity.x <= 10004.0) {
                gl_Position = vec4(10.0);

                #if SHADOW_TYPE == 3
                    shadowCascadePos = vec2(10.0);
                #endif

                return;
            }
            //else {
        #endif

        vec4 pos = gl_Vertex;

        #ifdef ENABLE_WAVING
            if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0)
                pos.xyz += GetWavingOffset();
        #endif

        vec4 viewPos = gl_ModelViewMatrix * pos;

        #if SHADOW_TYPE == 3
            cascadeSizes[0] = GetCascadeDistance(0);
            cascadeSizes[1] = GetCascadeDistance(1);
            cascadeSizes[2] = GetCascadeDistance(2);
            cascadeSizes[3] = GetCascadeDistance(3);

            mat4 matShadowProjections[4];
            matShadowProjections[0] = GetShadowCascadeProjectionMatrix(0);
            matShadowProjections[1] = GetShadowCascadeProjectionMatrix(1);
            matShadowProjections[2] = GetShadowCascadeProjectionMatrix(2);
            matShadowProjections[3] = GetShadowCascadeProjectionMatrix(3);

            int shadowCascade = GetShadowCascade(matShadowProjections);
            shadowCascadePos = GetShadowCascadeClipPos(shadowCascade);
            gl_Position = matShadowProjections[shadowCascade] * viewPos;

            gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
            gl_Position.xy = gl_Position.xy * 0.5 + shadowCascadePos;
            gl_Position.xy = gl_Position.xy * 2.0 - 1.0;
        #else
            gl_Position = gl_ProjectionMatrix * viewPos;

            #if SHADOW_TYPE == 2
                gl_Position.xyz = distort(gl_Position.xyz);
            #endif
        #endif

        // #ifdef SHADOW_EXCLUDE_FOLIAGE
        //     }
        // #endif

        #if defined SSS_ENABLED || defined RSM_ENABLED
            vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
            vec3 viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
            vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * at_tangent.w);

            #if !defined RSM_ENABLED //&& DEBUG_SHADOW_BUFFER != 2
                mat3 matViewTBN;
            #endif

            matViewTBN = mat3(
                viewTangent.x, viewBinormal.x, viewNormal.x,
                viewTangent.y, viewBinormal.y, viewNormal.y,
                viewTangent.z, viewBinormal.z, viewNormal.z);

            viewPosTan = matViewTBN * viewPos.xyz;
        #endif
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D texture;

    uniform mat4 shadowModelViewInverse;

    //#if MC_VERSION >= 11700 && defined IS_OPTIFINE
    //    uniform float alphaTestRef;
    //#endif

    #ifdef RSM_ENABLED
        uniform sampler2D normals;
    #endif

    #if defined SSS_ENABLED // || defined RSM_ENABLED
        uniform sampler2D specular;
    #endif

    #include "/lib/lighting/hcm.glsl"
    #include "/lib/lighting/material.glsl"
    #include "/lib/lighting/material_reader.glsl"

    /* RENDERTARGETS: 0 */
    layout(location = 0) out uvec2 outColor0;


    void main() {
        #if SHADOW_TYPE == 3
            vec2 screenCascadePos = gl_FragCoord.xy / shadowMapSize - shadowCascadePos;
            if (screenCascadePos.x < 0 || screenCascadePos.x >= 0.5
             || screenCascadePos.y < 0 || screenCascadePos.y >= 0.5) discard;
        #endif

        vec4 colorMap = texture2D(texture, texcoord) * glcolor;
        if (colorMap.a < 0.5) discard;

        // #ifdef RSM_ENABLED
        //     float specularMapR = texture2D(specular, texcoord).r;

        //     colorMap.rgb = RGBToLinear(colorMap.rgb);
        //     colorMap.rgb *= 0.25 + 0.75 * specularMapR*specularMapR;
        //     colorMap.rgb = LinearToRGB(colorMap.rgb);
        // #endif

        vec3 viewNormal = vec3(0.0);
        #if defined RSM_ENABLED
            vec2 normalMap = texture2D(normals, texcoord).rg;
            viewNormal = RestoreNormalZ(normalMap) * matViewTBN;
        #endif

        float sss = 0.0;
        #ifdef SSS_ENABLED
            vec3 specularMap = texture2D(specular, texcoord).rgb;
            vec3 viewDirT = -normalize(viewPosTan);

            sss = GetLabPbr_SSS(specularMap.b) * abs(viewDirT.z);

            //if (sss > EPSILON) {
            //    vec3 viewDirT = -normalize(viewPosTan);

                //float f0 = GetLabPbr_F0(specularMap.g);
                //if (f0 < EPSILON) f0 = 0.04;

                //float ior = f0ToIOR(f0);
                //vec3 refractDir = refract(viewDirT, texNormalT, IOR_AIR / ior);

                //float NoVm = abs(dot(texNormalT, viewDirT));

                //float roughL = specularMap.r*specularMap.r;

                //float F = SchlickRoughness(f0, NoVm, roughL);
                //final.r = sss;// * max(-refractDir.z, 0.0);// * (1.0 - F);
                //final.rgb = -refractDir.zzz;

            //    sss *= abs(viewDirT.z);
            //}
        #endif

        outColor0.r = packUnorm4x8(vec4(colorMap.rgb, sss));
        outColor0.g = packUnorm2x16(viewNormal.xy * 0.5 + 0.5);
    }
#endif
