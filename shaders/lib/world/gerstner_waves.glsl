const vec4 Wave_1 = vec4(1.0, 0.0, 0.24, 2.0);
const vec4 Wave_2 = vec4(0.0, 1.0, 0.12, 2.0);
const vec4 Wave_3 = vec4(1.0, 1.0, 0.18, 2.0);
// const vec4 Wave_1 = vec4(1.0, 2.0, 0.120,  4.0);
// const vec4 Wave_2 = vec4(0.7, 1.0, 0.080, 8.0);
// const vec4 Wave_3 = vec4(1.0, 0.5, 0.050,  4.0);

// wave: (dirX, dirY, steepness, wavelength)
vec3 GerstnerWave(const in vec3 srcPos, inout vec3 tangent, inout vec3 binormal, const in vec4 wave) {
    vec2 d = normalize(wave.xy);
    float k = 2.0 * PI / wave.w;
    float c = sqrt(9.8 / k);
    float f = k * (dot(d, srcPos.xz) - c * frameTimeCounter);
    float a = wave.z / k;

    tangent += vec3(
        -d.x * d.x * (wave.z * sin(f)),
         d.x * (wave.z * cos(f)),
        -d.x * d.y * (wave.z * sin(f)));

    binormal += vec3(
        -d.x * d.y * (wave.z * sin(f)),
         d.y * (wave.z * cos(f)),
        -d.y * d.y * (wave.z * sin(f)));

    return vec3(
        d.x * (a * cos(f)),
        a   * sin(f),
        d.y * (a * cos(f)));
}

void ApplyGerstnerWaves(inout vec3 localPos, out vec3 normal) {
    vec3 srcPos = localPos + cameraPosition;
    vec3 binormal = vec3(0.0);
    vec3 tangent = vec3(0.0);

    localPos.y += GerstnerWave(srcPos, tangent, binormal, Wave_1).y;
    localPos.y += GerstnerWave(srcPos, tangent, binormal, Wave_2).y;
    localPos.y += GerstnerWave(srcPos, tangent, binormal, Wave_3).y;

    normal = normalize(cross(binormal, tangent));
}
