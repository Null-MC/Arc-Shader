#define RENDER_GBUFFER
#define RENDER_LINE

#define LINE_WIDTH 3.0
#define VIEW_SCALE 1.0

#ifdef RENDER_VERTEX
    in vec3 vaPosition;
    in vec3 vaNormal;

    out vec2 lmcoord;
    out vec3 localPos;

    uniform mat4 modelViewMatrix;
    uniform mat4 projectionMatrix;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
    uniform vec3 cameraPosition;
    uniform float viewWidth;
    uniform float viewHeight;


    void main() {
        #if BLOCK_OUTLINE == BLOCK_OUTLINE_NONE
            gl_Position = vec4(10.0);
        #else
            lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

            vec2 viewSize = vec2(viewWidth, viewHeight);

            vec4 linePosStart = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vec4(vaPosition, 1.0)));
            vec3 ndc1 = linePosStart.xyz / linePosStart.w;

            vec4 linePosEnd = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vec4(vaPosition + vaNormal, 1.0)));
            vec3 ndc2 = linePosEnd.xyz / linePosEnd.w;

            vec2 lineScreenDirection = normalize((ndc2.xy - ndc1.xy) * viewSize);
            vec2 lineOffset = vec2(-lineScreenDirection.y, lineScreenDirection.x) * LINE_WIDTH / viewSize;

            if (lineOffset.x < 0.0) lineOffset = -lineOffset;
            if (gl_VertexID % 2 != 0) lineOffset = -lineOffset;
            gl_Position = vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);

            #if BLOCK_OUTLINE == BLOCK_OUTLINE_FANCY
                localPos = (gbufferModelViewInverse * (gbufferProjectionInverse * gl_Position)).xyz + cameraPosition;
            #endif
        #endif
    }
#endif

#ifdef RENDER_FRAG
    in vec2 lmcoord;
    in vec3 localPos;

    /* RENDERTARGETS: 2 */
    out uvec4 outColor0;


    void main() {
        vec4 colorMap = vec4(0.0, 0.0, 0.0, 1.0);
        vec4 normalMap = vec4(0.5, 0.5, 1.0, 0.0);
        vec4 specularMap = vec4(0.0, 0.0, 0.0, 0.0);
        vec4 lightingMap = vec4(0.0, 0.0, 1.0, 0.0);

        #if BLOCK_OUTLINE == BLOCK_OUTLINE_WHITE
            colorMap.rgb = vec3(0.8);
        #elif BLOCK_OUTLINE == BLOCK_OUTLINE_FANCY
            float offset = (localPos.x + localPos.y + localPos.z) * 10.0;
            colorMap.rgb = step(1.0, mod(offset, 2.0)) * vec3(1.0, 1.0, 0.0);
            specularMap.a = 0.06;
        #endif

        uvec4 data;
        data.r = packUnorm4x8(colorMap);
        data.g = packUnorm4x8(normalMap);
        data.b = packUnorm4x8(specularMap);
        data.a = packUnorm4x8(lightingMap);
        outColor0 = data;
    }
#endif
