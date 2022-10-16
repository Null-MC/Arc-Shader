float GetContactShadow(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 shadowRay) {
    vec3 startClipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 endClipPos = unproject(gbufferProjection * vec4(viewPos + shadowRay, 1.0)) * 0.5 + 0.5;

    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);

    vec3 screenRay = endClipPos - startClipPos;

    int stepCount;
    if (abs(screenRay.y) > abs(screenRay.x)) {
        stepCount = int(ceil(abs(screenRay.y) / pixelSize.y));
    }
    else {
        stepCount = int(ceil(abs(screenRay.x) / pixelSize.x));
    }

    vec3 screenStep = screenRay / stepCount;// * 2.0;
    stepCount = min(stepCount, 128);

    screenStep *= 6.0;

    #ifdef SHADOW_CONTACT_DITHER
        //startClipPos.xy += screenStep.xy * 0.2*GetScreenBayerValue();
        startClipPos += screenStep * GetScreenBayerValue();
    #endif

    float texDepth;
    vec3 tracePos;

    int i = 1;
    float shadow = 1.0;
    for (; i <= stepCount && shadow > EPSILON; i++) {
        tracePos = startClipPos + i*screenStep;
        if (clamp(tracePos, vec3(0.0), vec3(1.0 - EPSILON)) != tracePos) break;//return 1.0;

        ivec2 iuv = ivec2(tracePos.xy * viewSize);
        texDepth = texelFetch(depthtex, iuv, 0).r;
        if (texDepth > tracePos.z - EPSILON) continue;
        if (texDepth < tracePos.z - 0.00001*i) continue;

        //if (screenStep.z > 0.0 && texDepth < startClipPos.z) continue;
        //if (screenStep.z < 0.0 && texDepth > startClipPos.z) continue;

        float d = 0.001*(i*i);
        if (linearizeDepthFast(texDepth, near, far) > linearizeDepthFast(tracePos.z, near, far) - d) continue;

        shadow -= 9.0 / i;
    }

    return max(shadow, 0.0);
}
