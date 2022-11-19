// https://www.shadertoy.com/view/tdSXzD

vec3 hash33_stars(in vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p.zxy, p.yxz + 19.27);
    return fract(vec3(p.x * p.y, p.z*p.x, p.y*p.z));
}

float noise(const in vec2 v) { 
    return textureLod(noisetex, (v + 0.5) / 256.0, 0.0).r; 
}

vec3 GetStarLight(const in vec3 D) {
    float t = frameTimeCounter / 3.6;

    float L1 =  cameraPosition.y / D.y;
    vec3 O1 = cameraPosition + D * L1;

    vec3 D1 = normalize(D + vec3(1.0, 0.0009*sin(t+6.2831*noise(O1.xz + vec2(0.0, t*0.8))), 0.0));

    vec3 c = vec3(0.0);
    float res = viewWidth;

	for (int i = 0; i < 4; i++) {
        vec3 q = fract(D1 * (0.15*res)) - 0.5;
        vec3 id = floor(D1 * (0.15*res));
        vec2 rn = hash33_stars(id).xy;
        float c2 = 1.0 - smoothstep(0.0, 0.6, length(q));
        c2 *= step(rn.x, 0.0005 + pow2(i) * 0.001);
        c += c2 * (mix(vec3(1.0, 0.49, 0.1), vec3(0.75, 0.9, 1.0), rn.y) * 0.1 + 0.9);
        D1 *= 1.3;
    }

    return pow2(c) * 0.8;
}
