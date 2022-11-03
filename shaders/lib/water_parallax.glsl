void GetWaterParallaxCoord(inout vec3 coordDepth, const in mat2 dFdXY, const in vec3 tanViewDir, const in float viewDist, const in float waterDepth) {
    const float waterParallaxDepth = WATER_WAVE_DEPTH / (2.0*WATER_RADIUS);

    float viewDistF = saturate(viewDist / WATER_RADIUS);
    //viewDistF = min(1.0 - viewDistF, viewDistF*40.0);

    viewDistF = max(viewDistF, 1.0-viewDistF*40.0);

    //float depthLimit = isEyeInWater == 1 ? 1.0 - viewDistF : viewDistF;

    #ifdef PARALLAX_DEPTH_WRITE
        int maxSampleCount = WATER_PARALLAX_SAMPLES;
    #else
        int maxSampleCount = max(int(min(viewDistF, 0.2*waterDepth) * WATER_PARALLAX_SAMPLES), 1);
    #endif

    vec2 stepCoord = tanViewDir.xy * waterParallaxDepth / (1.0 + tanViewDir.z * maxSampleCount);
    float stepDepth = rcp(maxSampleCount);// * viewDistF;

    float prevTexDepth;

    float texDepth = isEyeInWater == 1 ? 0.0 : 1.0;
    //float depthDist;// = isEyeInWater == 1 ? 0.0 : 1.0;

    int i;
    for (i = 1; i <= maxSampleCount; i++) {
        prevTexDepth = texDepth;

        vec2 traceCoord = coordDepth.xy - i * stepCoord;

        vec2 sampleCoord = floor(traceCoord * WATER_RESOLUTION) / WATER_RESOLUTION;

        vec4 samples = textureGather(BUFFER_WATER_WAVES, sampleCoord, 0);
        vec2 f = fract(traceCoord * WATER_RESOLUTION);
        texDepth = LinearBlend4(samples, f);
        
        //depthDist = 1.0 - i * stepDepth - texDepth;

        float traceDepth = i * stepDepth;

        float dist2 = saturate((viewDist + (traceDepth / -tanViewDir.z * WATER_WAVE_DEPTH)) / WATER_RADIUS);

        if (isEyeInWater == 1) {
            if (traceDepth >= min(texDepth, 1.0 - dist2)) break;
        }
        else {
            if (1.0 - traceDepth <= max(texDepth, dist2)) break;
        }
    }

    i = max(i - 1, 0);
    int pI = max(i - 1, 0);

    vec2 currentTraceOffset = coordDepth.xy - i * stepCoord;
    vec2 prevTraceOffset = coordDepth.xy - pI * stepCoord;

    float currentTraceDepth = isEyeInWater == 1 ? i * stepDepth : 1.0 - i * stepDepth;
    float prevTraceDepth = isEyeInWater == 1 ? pI * stepDepth : 1.0 - pI * stepDepth;

    float t = saturate((prevTraceDepth - prevTexDepth) / max(texDepth - prevTexDepth + prevTraceDepth - currentTraceDepth, EPSILON));

    coordDepth.xy = fract(mix(prevTraceOffset, currentTraceOffset, t));
    coordDepth.z = mix(prevTraceDepth, currentTraceDepth, t);
}
