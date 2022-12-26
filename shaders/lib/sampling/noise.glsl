#define UI0 1597334673U
#define UI1 3812015801U
//#define UI2 uvec2(UI0, UI1)
#define UI3 uvec3(UI0, UI1, 2798796415U)
#define UIF (1.0 / float(0xffffffffU))


float hash12(const in uvec2 x) {
    uvec2 q = 1103515245U * ((x>>1U) ^ (x.yx   ));
    uint  n = 1103515245U * ((q.x  ) ^ (q.y>>3U));
    return float(n) * UIF;
}

vec2 hash22(const in vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

vec2 hash23(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

vec3 hash32(const in uvec2 q) {
    uvec3 n = q.xyx * UI3;
    n = (n.x ^ n.y ^n.z) * UI3;
    return vec3(n) * UIF;
}

vec3 hash33(const in uvec3 p) {
    uvec3 q = p * UI3;
    q = (q.x ^ q.y ^ q.z) * UI3;
    return -1.0 + 2.0 * vec3(q) * UIF;
}

float hash12(const in vec2 x) {return hash12(uvec2(x));}
vec3 hash32(const in vec2 q) {return hash32(uvec2(q));}
vec3 hash33(const in vec3 p) {return hash33(uvec3(p));}
