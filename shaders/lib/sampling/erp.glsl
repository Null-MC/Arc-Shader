// Equirectangular Projection

vec3 DirectionFromUV(const in vec2 uv) {
    vec2 sphereCoord = (uv - vec2(0.5, 0.0)) * vec2(TAU, PI);

    vec2 _sin = sin(sphereCoord);
    vec2 _cos = cos(sphereCoord);
    
    return vec3(_cos.x * _sin.y, _cos.y, _sin.x * _sin.y);
}

vec2 DirectionToUV(const in vec3 dir) {
    if (dir.y >  0.9999) return vec2(0.5, 0.0);
    if (dir.y < -0.9999) return vec2(0.5, 1.0);

    return vec2(
        atan(dir.z, dir.x) * rcp(TAU) + 0.5,
        acos(dir.y) * rcp(PI));
}
