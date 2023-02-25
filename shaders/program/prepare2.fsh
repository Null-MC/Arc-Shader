//#define RENDER_IRRADIANCE_LUT
#define RENDER_PREPARE
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

uniform sampler2D BUFFER_SKY_LUT;
uniform sampler3D TEX_SUN_TRANSMIT;
uniform sampler3D TEX_MULTI_SCATTER;

uniform vec3 cameraPosition;
uniform float rainStrength;

#include "/lib/sky/hillaire_common.glsl"
#include "/lib/sky/hillaire_render.glsl"
#include "/lib/sampling/erp.glsl"


/* RENDERTARGETS: 11 */
layout(location = 0) out vec3 outColor0;


vec3 CalculateIrradiance(const in vec3 normal) {
    const float sampleDelta = 0.2;

    vec3 up    = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, normal));
    up         = normalize(cross(normal, right));

    float nrSamples = 0.0;
    vec3 irradiance = vec3(0.0);  
    for (float phi = 0.0; phi < TAU; phi += sampleDelta) {
        for (float theta = 0.0; theta < (0.5 * PI); theta += sampleDelta) {
            // spherical to cartesian (in tangent space)
            vec3 tangentSample = vec3(sin(theta) * cos(phi),  sin(theta) * sin(phi), cos(theta));

            // tangent space to world
            vec3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * normal; 

            vec3 skyColor = getValFromSkyLUT(cameraPosition.y, sampleVec, 0.0);
            irradiance += skyColor * cos(theta) * sin(theta);
            nrSamples++;
        }
    }

    return PI * irradiance * rcp(nrSamples);
}

void main() {
    vec3 normal = DirectionFromUV(texcoord);
    outColor0 = CalculateIrradiance(normal);
}
