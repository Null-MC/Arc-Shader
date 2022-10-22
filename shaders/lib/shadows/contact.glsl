float GetContactShadow(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 lightDir, const in float minDist, out float lightDist) {
    vec3 startClipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 endClipPos = unproject(gbufferProjection * vec4(viewPos + lightDir, 1.0)) * 0.5 + 0.5;

    vec3 screenRay = normalize(endClipPos - startClipPos);
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 iuv_start = ivec2(startClipPos.xy * viewSize);
    vec2 pixelSize = rcp(viewSize);

    if (abs(screenRay.y) > abs(screenRay.x))
        screenRay *= pixelSize.y / abs(screenRay.y);
    else
        screenRay *= pixelSize.x / abs(screenRay.x);

    screenRay *= 3.0;

    #ifdef SHADOW_CONTACT_DITHER
        startClipPos += screenRay * GetScreenBayerValue();
    #endif

    float texDepth;
    vec3 tracePos;

    vec3 lastHitPos = startClipPos;

    float startDepthLinear = linearizeDepthFast(startClipPos.z, near, far);
    float viewDist = saturate(viewPos.z / far);

    int sampleCount = int(mix(24, 64, viewDist));

    int i;
    float shadow = 1.0;
    for (i = 1; i <= sampleCount; i++) {
        tracePos = startClipPos + i*screenRay;
        if (clamp(tracePos, vec3(0.0), vec3(1.0 - EPSILON)) != tracePos) break;

        ivec2 iuv = ivec2(tracePos.xy * viewSize);
        if (iuv == iuv_start) continue;

        texDepth = texelFetch(depthtex, iuv, 0).r;

        if (texDepth > tracePos.z - EPSILON) continue;

        float texDepthLinear = linearizeDepthFast(texDepth, near, far);
        float traceDepthLinear = linearizeDepthFast(tracePos.z, near, far);

        if (screenRay.z >= 0.0) {
            if (texDepthLinear < startDepthLinear - 0.0025 * i*i) continue;
        }
        else {
            if (texDepthLinear > startDepthLinear) continue;
            if (texDepthLinear < traceDepthLinear - 0.01 * i*i) continue;
        }

        //if (screenRay.z > 0.0 && texDepth < startClipPos.z) continue;
        //if (screenRay.z < 0.0 && texDepth > startClipPos.z) continue;

        //if (texDepthLinear > traceDepthLinear - 0.001 * i) continue;

        lastHitPos = tracePos;
        shadow -= 9.0 / i;
    }

    vec3 hitViewPos = unproject(gbufferProjectionInverse * vec4(lastHitPos * 2.0 - 1.0, 1.0));
    lightDist = distance(viewPos, hitViewPos);

    return max(shadow, 0.0);
}
