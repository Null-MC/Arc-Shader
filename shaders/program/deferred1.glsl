#define RENDER_DEFERRED
//#define RENDER_WATER_WAVES

#ifdef RENDER_VERTEX
    out vec2 texcoord;

    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    in vec2 texcoord;

    uniform vec3 cameraPosition;
    uniform float frameTimeCounter;
    uniform float rainStrength;

    #include "/lib/world/wind.glsl"
    #include "/lib/world/water.glsl"

    /* RENDERTARGETS: 11 */
    out float outColor0;

    void main() {
        vec2 pos = WATER_SCALE * ((texcoord - 0.5) + rcp(2.0*WATER_RADIUS) * cameraPosition.xz);
        float windSpeed = GetWindSpeed();

        outColor0 = GetWaves(pos, windSpeed, WATER_OCTAVES_NEAR);
    }
#endif
