// THIS FILE IS PUBLIC DOMAIN SO USE IT HOWEVER YOU WANT!
// to make it compatible with your shaderpack use:
//#define PHYSICS_OCEAN_SUPPORT
// at the top of your file. When used my mod no longer injects code into
// your shaderpack. It replaces this define statement (before compilation) with
//#define PHYSICS_OCEAN
// so you can use
//#ifdef PHYSICS_OCEAN
//#endif
// to customize the water for the physics ocean 


// just some basic consts for the wave function based on afl_ext's shader https://www.shadertoy.com/view/Xdlczl
// the overall shape must stay consistent because it is also computed on the CPU side
// to offset entities (though a custom CPU integration of your shader is possible by
// contacting me on my discord server https://discord.gg/VsNs9xP)
const int PHYSICS_ITERATIONS_OFFSET = 13;
const float PHYSICS_DRAG_MULT = 0.048;
const float PHYSICS_XZ_SCALE = 0.035;
const float PHYSICS_TIME_MULTIPLICATOR = 0.45;
const float PHYSICS_W_DETAIL = 0.75;
const float PHYSICS_FREQUENCY = 6.0;
const float PHYSICS_SPEED = 2.0;
const float PHYSICS_FREQUENCY_MULT = 1.18;
const float PHYSICS_SPEED_MULT = 1.07;
const float PHYSICS_ITER_INC = 12.0;
const float PHYSICS_NORMAL_STRENGTH = 0.6;

// this is the surface detail from the physics options, ranges from 13 to 48 (yeah I know weird)
uniform int physics_iterationsNormal;
// used to offset the 0 point of wave meshes to keep the wave function consistent even
// though the mesh totally changes
uniform vec2 physics_waveOffset;
// time in seconds that can go faster dependent on weather conditions (affected by weather strength
// multiplier in ocean settings
uniform float physics_gameTime;
// base value is 13 and gets multiplied by wave height in ocean settings
uniform float physics_oceanHeight;
// basic texture to determine how shallow/far away from the shore the water is
uniform sampler2D physics_waviness;

#ifdef RENDER_VERTEX
    out vec3 physics_localPosition;
#endif

#ifdef RENDER_FRAG
    in vec3 physics_localPosition;
#endif

float physics_waveHeight(vec2 position, int iterations, float factor, float time) {
    position = (position - physics_waveOffset) * PHYSICS_XZ_SCALE;
	float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;
    float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
    
    for (int i = 0; i < iterations; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        position -= force * PHYSICS_DRAG_MULT;
        height += wave * weight;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= 0.8;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    return height / waveSum * physics_oceanHeight * factor - physics_oceanHeight * factor * 0.5;
}

vec2 physics_waveDirection(vec2 position, int iterations, float time) {
    position = (position - physics_waveOffset) * PHYSICS_XZ_SCALE;
	float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float waveSum = 0.0;
    float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
    vec2 dx = vec2(0.0);
    
    for (int i = 0; i < iterations; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        dx += force / pow(weight, PHYSICS_W_DETAIL); 
        position -= force * PHYSICS_DRAG_MULT;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= 0.8;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    return vec2(dx / pow(waveSum, 1.0 - PHYSICS_W_DETAIL));
}

vec3 physics_waveNormal(vec2 position, float factor, float time) {
    vec2 wave = -physics_waveDirection(position, physics_iterationsNormal, time);
    float oceanHeightFactor = physics_oceanHeight / 13.0;
    float totalFactor = oceanHeightFactor * factor;
    return normalize(vec3(wave.x * totalFactor, PHYSICS_NORMAL_STRENGTH, wave.y * totalFactor));
}

// // VERTEX STAGE
// void main() {
// 	// basic texture to determine how shallow/far away from the shore the water is
// 	float waviness = textureLod(physics_waviness, gl_Vertex.xz / vec2(textureSize(physics_waviness, 0)), 0).r;
// 	// transform gl_Vertex (since it is the raw mesh, i.e. not transformed yet)
// 	vec4 finalPosition = vec4(gl_Vertex.x, gl_Vertex.y + physics_waveHeight(gl_Vertex.xz, PHYSICS_ITERATIONS_OFFSET, waviness, physics_gameTime), gl_Vertex.z, gl_Vertex.w);
// 	// pass this to the fragment shader to fetch the texture there for per fragment normals
//     physics_localPosition = finalPosition.xyz;
    
//     // now use finalPosition instead of gl_Vertex
// }

// // FRAGMENT STAGE
// void main() {
// 	// basic texture to determine how shallow/far away from the shore the water is
// 	float waviness = textureLod(physics_waviness, physics_localPosition.xz / vec2(textureSize(physics_waviness, 0)), 0.0).r;
// 	// normal is in world space
//     vec3 normal = physics_waveNormal(physics_localPosition.xz, waviness, physics_gameTime);
// }
