// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    vec3 clipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPos + reflectDir, 1.0)) * 0.5 + 0.5;

    vec3 screenRay = reflectClipPos - clipPos;
    float screenRayLength = length(screenRay);
    if (screenRayLength < EPSILON) return vec4(0.0);

    screenRay /= screenRayLength;

    vec2 viewSize = vec2(viewWidth, viewHeight) / SSR_SCALE;
    ivec2 iuv_start = ivec2(clipPos.xy * viewSize);
    vec2 ssrPixelSize = rcp(viewSize);

    if (abs(screenRay.y) > abs(screenRay.x))
        screenRay *= ssrPixelSize.y / abs(screenRay.y);
    else
        screenRay *= ssrPixelSize.x / abs(screenRay.x);

    #if SSR_QUALITY == 0
        screenRay *= 3.0;
    #elif SSR_QUALITY == 1
        screenRay *= 2.5;
    #else
        screenRay *= 2.0;
    #endif

    clipPos += screenRay * GetScreenBayerValue();

    const vec3 clipMin = vec3(0.0);
    const vec3 clipMax = vec3(1.0 - EPSILON);

    int i;
    float alpha = 0.0;
    float texDepth;
    vec3 tracePos;
    for (i = 1; i <= SSR_MAXSTEPS && alpha < EPSILON; i++) {
        tracePos = clipPos + i*screenRay;

        // if (tracePos.z >= 1.0) {
        //     alpha = 1.0;
        //     break;
        // }

        if (clamp(tracePos, clipMin, clipMax) != tracePos) break;

        ivec2 iuv = ivec2(tracePos.xy * viewSize);
        if (iuv == iuv_start) continue;

        texDepth = texelFetch(depthtex, iuv, 0).r;
        if (texDepth > 1.0 - EPSILON || texDepth >= tracePos.z) continue;

        if (screenRay.z > 0.0 && texDepth < clipPos.z) continue;

        float d = 0.0001*(i*i);
        if (linearizeDepthFast(texDepth, near, far) > linearizeDepthFast(tracePos.z, near, far) - d) continue;

        alpha = 1.0;
    }

    vec3 color = vec3(0.0);
    if (alpha > EPSILON) {
        vec2 alphaXY = saturate(20.0 * abs(vec2(0.5) - tracePos.xy) - 9.0);
        alpha = 1.0 - pow(maxOf(alphaXY), 4.0);
        //alpha = 1.0 - smoothstep(0.0, 1.0, maxOf(alphaXY));

        // This is a weird idea to cleanup reflection noise by
        // mixing 75% of the exact pixel, and 25% of the mipmap
        color = 0.75 * textureLod(BUFFER_HDR_PREVIOUS, tracePos.xy, 0).rgb / exposure;
        color += 0.25 * textureLod(BUFFER_HDR_PREVIOUS, tracePos.xy, lod).rgb / exposure;
    }

    return vec4(color, alpha);
}
