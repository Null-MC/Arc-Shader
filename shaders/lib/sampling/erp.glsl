// Equirectangular Projection

vec3 DirectionFromUV(const in vec2 uv) {
	vec2 sphereCoord = (uv - 0.5) * vec2(TAU, PI);

    return vec3(
    	cos(sphereCoord.y) * cos(sphereCoord.x),
        sin(sphereCoord.y),
        cos(sphereCoord.y) * sin(sphereCoord.x));
}

vec2 DirectionToUV(const in vec3 dir) {
    vec2 sphereCoord = vec2(
        atan(dir.z, dir.x),
        acos(dir.y));

    return sphereCoord / vec2(TAU, PI) + 0.5;
}
