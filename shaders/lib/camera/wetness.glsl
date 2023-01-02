#if WATER_CAMERA_BLUR == 2
    const int samples = 8;
    const int WET_BLUR_LOD = 3;
#else
    const int samples = 4;
    const int WET_BLUR_LOD = 3;
#endif

const int sLOD = 1 << WET_BLUR_LOD; // tile size = 2^LOD
const float sigma = float(samples) * 0.25;


float gaussian(inout vec2 i) {
    return exp(-0.5 * dot(i /= sigma, i)) / (6.28 * pow2(sigma));
}

vec3 SampleWetnessBlurred(const in sampler2D colortex, const in vec2 texcoord) {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);
    int s = samples / sLOD;

    vec4 O = vec4(0.0);
    
    for (int i = 0; i < s*s; i++) {
        vec2 d = vec2(i % s, i / s) * float(sLOD) - float(samples) / 2.0 + 0.5;
        O += gaussian(d) * vec4(textureLod(colortex, texcoord + d * pixelSize, WET_BLUR_LOD).rgb, 1.0);
    }
    
    return O.rgb / O.a;
}

vec2 GetWetnessSkew(const in vec2 texcoord) {
    const float waterSkewStrength = 0.001;
    const vec2 skewScale = vec2(48.0, 64.0);
    float time = 2.0 * (frameTimeCounter / 3.6) * TAU;

    vec2 texOffset = sin(texcoord.yx * skewScale + time + vec2(0.2, 0.8)) * waterSkewStrength;
    texOffset.x *= aspectRatio;

    // TODO: make skew distance depth-based?
    //float depth = textureLod(depthtex0, );

    return saturate(texcoord + texOffset);
}
