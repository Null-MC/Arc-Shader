// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    vec3 clipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPos + reflectDir, 1.0)) * 0.5 + 0.5;

    vec2 viewSize = vec2(viewWidth, viewHeight) / SSR_SCALE;
    //vec2 pixelSize = rcp(viewSize);
    vec2 ssrPixelSize = rcp(viewSize);

    vec3 screenRay = reflectClipPos - clipPos;
    //if (screenRay.z <= 0.0) return vec4(0.0);

    if (abs(screenRay.y) > abs(screenRay.x))
        screenRay *= ssrPixelSize.y / abs(screenRay.y);
    else
        screenRay *= ssrPixelSize.x / abs(screenRay.x);

    float texDepth;
    vec3 tracePos;

    screenRay *= 3.0;

    ivec2 iuv_start = ivec2(clipPos.xy * viewSize);
    clipPos += screenRay * GetScreenBayerValue();

    const vec3 clipMin = vec3(0.0);
    const vec3 clipMax = vec3(1.0 - EPSILON);

    int i = 1;
    float alpha = 0.0;
    for (; i <= SSR_STEPS && alpha < 0.5; i++) {
        tracePos = clipPos + i*screenRay;
        if (clamp(tracePos, clipMin, clipMax) != tracePos) break;

        ivec2 iuv = ivec2(tracePos.xy * viewSize);
        if (iuv == iuv_start) continue;

        texDepth = texelFetch(depthtex, iuv, 0).r;
        if (texDepth >= tracePos.z) continue;

        if (screenRay.z > 0.0 && texDepth < clipPos.z) continue;

        float d = 0.0001*(i*i);
        if (linearizeDepthFast(texDepth, near, far) > linearizeDepthFast(tracePos.z, near, far) - d) continue;

        alpha = 1.0;
    }

    vec3 color = vec3(0.0);
    if (alpha > EPSILON) {
        vec2 alphaXY = saturate(2.0 * abs(vec2(0.5) - tracePos.xy));
        alpha = 1.0 - pow(max(alphaXY.x, alphaXY.y), 4.0);

        //ivec2 iuv = ivec2(tracePos.xy * viewSize / exp2(lod));
        //color = texelFetch(BUFFER_HDR_PREVIOUS, iuv, lod).rgb;

        color = textureLod(BUFFER_HDR_PREVIOUS, tracePos.xy, lod).rgb;

        //vec2 mipTexSize = vec2(viewWidth, viewHeight) / exp2(lod + 1);
        //color = TextureLodLinearRGB(BUFFER_HDR_PREVIOUS, tracePos.xy, mipTexSize, lod);
    }

    return vec4(color, alpha);
}
