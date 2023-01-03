vec2 GetWetnessSkew(const in vec2 texcoord) {
    const float waterSkewStrength = 0.0006;
    const vec2 skewScale = vec2(24.0, 32.0);
    float time = 2.0 * (frameTimeCounter / 3.6) * TAU;

    vec2 texOffset = sin(texcoord.yx * skewScale + time + vec2(0.2, 0.8)) * waterSkewStrength;
    texOffset.x *= aspectRatio;

    // TODO: make skew distance depth-based?
    //float depth = textureLod(depthtex0, );

    return saturate(texcoord + texOffset);
}
