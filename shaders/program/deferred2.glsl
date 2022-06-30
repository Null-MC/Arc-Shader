#extension GL_ARB_shading_language_packing : enable

#define RENDER_DEFERRED
#define RENDER_RSM_FULL

varying vec2 texcoord;

#ifdef RENDER_VERTEX
	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	}
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex1;
    uniform sampler2D colortex5;
    uniform sampler2D colortex6;
    uniform usampler2D shadowcolor0;
    uniform sampler2D shadowcolor1;
    uniform sampler2D shadowtex1;
    uniform sampler2D depthtex0;

    uniform mat4 shadowProjectionInverse;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 shadowProjection;
    uniform mat4 shadowModelView;

    #if SHADOW_TYPE == 2
        #include "/lib/shadows/basic.glsl"
    #endif

    #include "/lib/sampling/rsm_151.glsl"
    #include "/lib/lighting/rsm.glsl"


	void main() {
        float clipDepth = texture2DLod(depthtex0, texcoord, 0).r;

        vec3 final = vec3(0.0);
        if (clipDepth < 1.0) {
            vec2 normalTex = texture2DLod(colortex1, texcoord, 0).rg;
            vec3 rsmNormalDepth = texture2DLod(colortex6, texcoord, 0).rgb;

            vec3 viewNormal = RestoreNormalZ(normalTex);
            vec3 rsmViewNormal = RestoreNormalZ(rsmNormalDepth.xy);

            //final = vec3(abs(rsmNormalDepth.z - clipDepth));
            //float d = dot(rsmViewNormal, viewNormal);
            //final = vec3(d * d);

            if (abs(rsmNormalDepth.z - clipDepth) < 0.001 && dot(rsmViewNormal, viewNormal) > 0.9) {
                final = texture2DLod(colortex5, texcoord, 0).rgb;
            }
            else {
                vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;

                vec4 localPos = gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clipPos, 1.0));
                localPos.xyz /= localPos.w;

                //vec2 normalTex = texture2DLod(colortex1, texcoord, 0).rg;
                vec3 localNormal = mat3(gbufferModelViewInverse) * viewNormal;

                vec4 shadowPos = shadowProjection * (shadowModelView * vec4(localPos.xyz, 1.0));

                #if SHADOW_TYPE == 2
                    float distortFactor = getDistortFactor(shadowPos.xy);
                    shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
                #endif

                shadowPos.xyz /= shadowPos.w;

                final = GetIndirectLighting_RSM(shadowPos.xy, localPos.xyz, localNormal);
                //final = vec3(1.0, 0.0, 0.0);
            }
        }

        //final = LinearToRGB(final);

	/* DRAWBUFFERS:7 */
		gl_FragData[0] = vec4(final, 1.0); //colortex7
	}
#endif
