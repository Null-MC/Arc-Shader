#define RENDER_DEFERRED
#define RENDER_RSM

varying vec2 texcoord;

#ifdef RENDER_VERTEX
	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	}
#endif

#ifdef RENDER_FRAG
    // uniform sampler2D colortex0;
    uniform sampler2D colortex1;
    // uniform sampler2D colortex2;
    // uniform sampler2D colortex3;

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
    //uniform float viewWidth;
    //uniform float viewHeight;

    #if SHADOW_TYPE == 2
        #include "/lib/shadows/basic.glsl"
    #endif

    #include "/lib/sampling/rsm_151.glsl"
    #include "/lib/lighting/rsm.glsl"

    /* RENDERTARGETS: 5,6 */
    layout(location = 0) out vec4 outColor;
    layout(location = 1) out vec3 outNormalDepth;


	void main() {
        float clipDepth = texture2DLod(depthtex0, texcoord, 0).r;

        vec3 color = vec3(0.0);
        vec2 normal = vec2(0.0);
        if (clipDepth < 1.0) {
            vec3 clipPos = vec3(texcoord, clipDepth) * 2.0 - 1.0;

            vec4 localPos = gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clipPos, 1.0));
            localPos.xyz /= localPos.w;

            normal = texture2DLod(colortex1, texcoord, 0).rg;
            vec3 localNormal = mat3(gbufferModelViewInverse) * RestoreNormalZ(normal);

            vec4 shadowPos = shadowProjection * (shadowModelView * vec4(localPos.xyz, 1.0));

            #if SHADOW_TYPE == 2
                float distortFactor = getDistortFactor(shadowPos.xy);
                shadowPos.xyz = distort(shadowPos.xyz, distortFactor);
            #endif

            shadowPos.xyz /= shadowPos.w;

            color = GetIndirectLighting_RSM(shadowPos.xy, localPos.xyz, localNormal);
        }

        //color = LinearToRGB(color);

		outColor = vec4(color, 1.0); //colortex5
        outNormalDepth = vec3(normal, clipDepth); //colortex6
	}
#endif
