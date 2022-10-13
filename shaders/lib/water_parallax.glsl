void GetWaterParallaxCoord(inout vec3 coordDepth, const in mat2 dFdXY, const in vec3 tanViewDir, const in float viewDist, const in float waterDepth) {
    const float waterParallaxDepth = WATER_WAVE_DEPTH / (2.0*WATER_RADIUS);

    //float viewDistF = 1.0 - saturate(viewDist / WATER_RADIUS);
    float viewDistF = saturate(viewDist / WATER_RADIUS);
    viewDistF = min(1.0 - viewDistF, viewDistF*40.0);

    //float maxDepth = viewDistF * waterParallaxDepth;

    float minDepth = max(1.0 - viewDistF, EPSILON);

    #ifdef PARALLAX_DEPTH_WRITE
        int maxSampleCount = WATER_PARALLAX_SAMPLES;//max(int(viewDistF * WATER_PARALLAX_SAMPLES), 1);
    #else
        int maxSampleCount = max(int(min(viewDistF, 0.2*waterDepth) * WATER_PARALLAX_SAMPLES), 1);
    #endif

    vec2 stepCoord = tanViewDir.xy * waterParallaxDepth / (1.0 + tanViewDir.z * maxSampleCount);
    //stepCoord = clamp(stepCoord, vec2(-0.1), vec2(0.1));
    float stepDepth = rcp(maxSampleCount);// * viewDistF;

    float prevTexDepth;

    int i;
    float texDepth = 1.0;
    float depthDist = 1.0;
    for (i = 1; i <= maxSampleCount && depthDist > minDepth; i++) {
        prevTexDepth = texDepth;
        vec2 traceCoord = coordDepth.xy - i * stepCoord;
        texDepth = textureGrad(BUFFER_WATER_WAVES, traceCoord, dFdXY[0], dFdXY[1]).r;
        //texDepth = textureLod(BUFFER_WATER_WAVES, traceCoord, 0).r;
        depthDist = 1.0 - i * stepDepth - texDepth;
    }

    i = max(i - 1, 0);
    int pI = max(i - 1, 0);

    vec2 currentTraceOffset = coordDepth.xy - i * stepCoord;
    float currentTraceDepth = 1.0 - i * stepDepth;
    vec2 prevTraceOffset = coordDepth.xy - pI * stepCoord;
    float prevTraceDepth = 1.0 - pI * stepDepth;

    float t = saturate((prevTraceDepth - prevTexDepth) / max(texDepth - prevTexDepth + prevTraceDepth - currentTraceDepth, EPSILON));

    coordDepth.xy = fract(mix(prevTraceOffset, currentTraceOffset, t));
    coordDepth.z = mix(prevTraceDepth, currentTraceDepth, t);
}
