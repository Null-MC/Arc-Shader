const mat4 BayerSamples = mat4(
    vec4(0.0000, 0.5000, 0.1250, 0.6250),
    vec4(0.7500, 0.2200, 0.8750, 0.3750),
    vec4(0.1875, 0.6875, 0.0625, 0.5625),
    vec4(0.9375, 0.4375, 0.8125, 0.3125));

float GetBayerValue(const in ivec2 position) {
    ivec2 offset = position % 4;
    return BayerSamples[offset.x][offset.y];
}

float GetScreenBayerValue() {
    return GetBayerValue(ivec2(gl_FragCoord.xy));
}
