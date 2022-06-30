#extension GL_ARB_shading_language_packing : enable

#define RENDER_COMPOSITE

varying vec2 texcoord;

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex0;

    #if defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER != 0
        uniform usampler2D shadowcolor0;
        uniform sampler2D shadowtex0;
        uniform sampler2D shadowtex1;
        uniform sampler2D colortex7;

        #if DEBUG_SHADOW_BUFFER == 2
            #include "/lib/lighting/material_reader.glsl"
        #endif
    #endif


    void main() {
        vec3 color = vec3(0.0);
        #if defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 1
            // Shadow Albedo
            uint data = texture2D(shadowcolor0, texcoord).r;
            color = unpackUnorm4x8(data).rgb;
        #elif defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 2
            // Shadow Normal
            uint data = texture2D(shadowcolor0, texcoord).g;
            color = GetLabPbr_Normal(unpackUnorm2x16(data));
        #elif defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 3
            // Shadow SSS
            uint data = texture2D(shadowcolor0, texcoord).r;
            color = unpackUnorm4x8(data).aaa;
        #elif defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 4
            // Shadow Depth [0]
            color = texture2D(shadowtex0, texcoord).rrr;
        #elif defined SHADOW_ENABLED && DEBUG_SHADOW_BUFFER == 5
            // Shadow Depth [1]
            color = texture2D(shadowtex1, texcoord).rrr;
        #elif defined RSM_ENABLED && DEBUG_SHADOW_BUFFER == 6
            // RSM
            color = texture2D(colortex7, texcoord).rgb;
        #else
            // None
            color = texture2D(colortex0, texcoord).rgb;
        #endif

    /* DRAWBUFFERS:4 */
        gl_FragData[0] = vec4(color, 1.0); //gaux1
    }
#endif
