#define UI0 1597334673U
#define UI1 3812015801U
//#define UI2 uvec2(UI0, UI1)
#define UI3 uvec3(UI0, UI1, 2798796415U)
#define UIF (1.0 / float(0xffffffffU))


float hash11(in float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    //p *= p + p;
    return fract((p + p) * p);
}

float hashU12(const in uvec2 x) {
    uvec2 q = 1103515245U * ((x>>1U) ^ (x.yx   ));
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

float hash21(const in vec2 p) {
    vec2 p2 = fract(p * vec2(123.34, 233.53));
    p2 += dot(p2, p2 + 23.234);
    return fract(p2.x * p2.y);
}

vec2 hash22(const in vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 hash23(const in vec3 seed) {
    vec3 p3 = fract(seed * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(const in uvec2 q) {
    uvec3 n = q.xyx * UI3;
    n = (n.x ^ n.y ^n.z) * UI3;
    return vec3(n) * UIF;
}

vec3 hash33(const in vec3 q) {
    vec3 p3 = fract(q * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

vec3 hashU33(const in uvec3 p) {
    uvec3 q = p * UI3;
    q = (q.x ^ q.y ^ q.z) * UI3;
    return -1.0 + 2.0 * vec3(q) * UIF;
}

//float hash12(const in vec2 x) {return hash12(uvec2(x));}
vec3 hash32(const in vec2 q) {return hash32(uvec2(q));}
//vec3 hash33(const in vec3 p) {return hash33(uvec3(p));}
