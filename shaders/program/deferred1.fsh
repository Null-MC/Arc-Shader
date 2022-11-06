#define RENDER_FRAG
#define RENDER_DEFERRED
//#define RENDER_WATER_WAVES

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

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
    float waveSpeed = GetWaveSpeed(windSpeed, 1.0); // TODO: skylight not available!
    //float waveDepth = GetWaveDepth();

    outColor0 = GetWaves(pos, 1.0, WATER_OCTAVES_NEAR);
}
