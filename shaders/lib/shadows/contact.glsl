float GetContactShadow(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 lightDir, const in float minDist, out float lightDist) {
    vec3 startClipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 endClipPos = unproject(gbufferProjection * vec4(viewPos + lightDir, 1.0)) * 0.5 + 0.5;

    vec3 screenRay = endClipPos - startClipPos;
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 iuv_start = ivec2(startClipPos.xy * viewSize);
    vec2 pixelSize = rcp(viewSize);

    if (abs(screenRay.y) > abs(screenRay.x))
        screenRay *= pixelSize.y / abs(screenRay.y);
    else
        screenRay *= pixelSize.x / abs(screenRay.x);

    screenRay *= 2.0;

    #ifdef SHADOW_CONTACT_DITHER
        startClipPos += screenRay * GetScreenBayerValue();
    #endif

    float texDepth;
    vec3 tracePos;

    vec3 lastHitPos = startClipPos;

    int i;
    float shadow = 1.0;
    for (i = 1; i <= 64; i++) {
        tracePos = startClipPos + i*screenRay;
        if (clamp(tracePos, vec3(0.0), vec3(1.0 - EPSILON)) != tracePos) break;

        ivec2 iuv = ivec2(tracePos.xy * viewSize);
        if (iuv == iuv_start) continue;

        texDepth = texelFetch(depthtex, iuv, 0).r;

        if (texDepth > tracePos.z - EPSILON) continue;
        //if (texDepth < tracePos.z - 0.00001*i) continue;

        if (screenRay.z > 0.0 && texDepth < startClipPos.z) continue;
        if (screenRay.z < 0.0 && texDepth > startClipPos.z) continue;

        float d = 0.001*i;
        if (linearizeDepthFast(texDepth, near, far) > linearizeDepthFast(tracePos.z, near, far) - d) continue;

        lastHitPos = tracePos;
        shadow -= 9.0 / i;
    }

    vec3 hitViewPos = unproject(gbufferProjectionInverse * vec4(lastHitPos * 2.0 - 1.0, 1.0));
    lightDist = distance(viewPos, hitViewPos);

    return max(shadow, 0.0);
}
