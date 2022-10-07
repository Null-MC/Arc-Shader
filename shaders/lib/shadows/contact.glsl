float GetContactShadow(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 shadowRay) {
    vec3 startClipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 endClipPos = unproject(gbufferProjection * vec4(viewPos + shadowRay, 1.0)) * 0.5 + 0.5;

    vec2 pixelSize = rcp(vec2(viewWidth, viewHeight));

    vec3 screenRay = endClipPos - startClipPos;

    int stepCount;
    if (abs(screenRay.y) > abs(screenRay.x)) {
        stepCount = int(ceil(abs(screenRay.y) / pixelSize.y));
    }
    else {
        stepCount = int(ceil(abs(screenRay.x) / pixelSize.x));
    }

    vec3 screenStep = screenRay / stepCount;// * 2.0;
    stepCount = min(stepCount, 60);

    #ifdef SHADOW_CONTACT_DITHER
        startClipPos.xy += screenStep.xy * 0.2*GetScreenBayerValue();
    #endif

    //screenStep *= 1.5;

    float texDepth;
    vec3 tracePos;

    int i = 1;
    float shadow = 1.0;
    for (; i <= stepCount && shadow > EPSILON; i++) {
        tracePos = startClipPos + i*screenStep;

        if (tracePos.x <= 0.0 || tracePos.x >= 1.0
         || tracePos.y <= 0.0 || tracePos.y >= 1.0
         || tracePos.z <= 0.0 || tracePos.z >= 1.0) return 1.0;

        //if (abs(tracePos.x - startClipPos.x) < pixelSize.x
        // && abs(tracePos.y - startClipPos.y) < pixelSize.y) continue;
        //float traceDepthLinear = linearizeDepthFast(tracePos.z, near, far);

        texDepth = textureLod(depthtex, tracePos.xy, 0).r;
        //float texDepthLinear = linearizeDepthFast(texDepth, near, far);

        //float depthDeltaMax = mix(0.08, 0.4, tracePos.z);

        //shadow = step(depthDelta, 0.0) * step(depthDelta, depthDeltaMax);

        //if (depthDelta > 0 && depthDelta < depthDeltaMax) shadow = 0.0;
        if (tracePos.z <= texDepth) continue;

        // if (texDepth >= tracePos.z) continue;

        float d = 0.001 * i;//001 * i*i;
        if (linearizeDepthFast(tracePos.z, near, far) <= linearizeDepthFast(texDepth, near, far) + d) continue;

        shadow -= 4.0 / i;
    }

    return max(shadow, 0.0);
}
