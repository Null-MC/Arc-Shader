#define UI0 1597334673U
#define UI1 3812015801U
//#define UI2 uvec2(UI0, UI1)
#define UI3 uvec3(UI0, UI1, 2798796415U)
#define UIF (1.0 / float(0xffffffffU))


float hash11(in float seed) {
    float p = fract(seed * 0.1031);
    p *= p + 33.33;
    return fract((p + p) * p);
}

float hashU12(const in uvec2 seed) {
    uvec2 q = 1103515245U * ((seed>>1U) ^ (seed.yx   ));
    uint  n = 1103515245U * ((q.x  ) ^ (q.y>>3U));
    return float(n) * UIF;
}

float hash12(const in vec2 seed) {
    vec3 p3  = fract(vec3(seed.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(const in vec3 seed) {
    vec3 p3 = fract(seed * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float hash14(const in vec4 seed) {
    vec4 p4 = fract(seed * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.x + p4.y) * (p4.z + p4.w));
}

float hash21(const in vec2 seed) {
    vec2 p2 = fract(seed * vec2(123.34, 233.53));
    p2 += dot(p2, p2 + 23.234);
    return fract(p2.x * p2.y);
}

vec2 hash22(const in vec2 seed) {
    vec3 p3 = fract(vec3(seed.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 hash23(const in vec3 seed) {
    vec3 p3 = fract(seed * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(const in uvec2 seed) {
    uvec3 n = seed.xyx * UI3;
    n = (n.x ^ n.y ^n.z) * UI3;
    return vec3(n) * UIF;
}

vec3 hash33(const in vec3 seed) {
    vec3 p3 = fract(seed * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// vec3 hash34(const in vec4 seed) {
//     vec4 p4 = fract(seed * vec4(0.1031, 0.1030, 0.0973, 0.1099));
//     p4 += dot(p4, p4.wzxy + 33.33);
//     return fract((p4.xxy + p4.yxx) * (p4.zyx + p4.wy_));
// }

vec3 hashU33(const in uvec3 seed) {
    uvec3 q = seed * UI3;
    q = (q.x ^ q.y ^ q.z) * UI3;
    return -1.0 + 2.0 * vec3(q) * UIF;
}

vec4 hash44(const in vec4 seed) {
    vec4 p4 = fract(seed * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

//float hash12(const in vec2 x) {return hash12(uvec2(x));}
//vec3 hash32(const in vec2 seed) {return hash32(uvec2(seed));}
//vec3 hash33(const in vec3 p) {return hash33(uvec3(p));}
