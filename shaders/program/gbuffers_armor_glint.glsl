#define RENDER_ARMOR_GLINT

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#ifdef RENDER_VERTEX
    void main() {
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        glcolor = gl_Color;
        
        //use same transforms as entities and hand to avoid z-fighting issues
        gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D lightmap;
    uniform sampler2D gtexture;

    /* RENDERTARGETS: 0 */
    out vec4 outColor0;


    void main() {
        vec4 color = texture(gtexture, texcoord);
        color.rgb *= glcolor.rgb;

        color *= texture(lightmap, lmcoord);

        #if !defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE
            color.rgb *= glcolor.a;
        #endif

        outColor0 = color;
    }
#endif
