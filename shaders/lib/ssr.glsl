// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    vec3 clipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPos + reflectDir, 1.0)) * 0.5 + 0.5;

    vec2 pixelSize = rcp(vec2(viewWidth, viewHeight));
    vec2 ssrPixelSize = SSR_SCALE * pixelSize;

    vec3 screenRay = reflectClipPos - clipPos;
    if (screenRay.z <= 0.0) return vec4(0.0);

    if (abs(screenRay.y) > abs(screenRay.x))
        screenRay *= ssrPixelSize.y / abs(screenRay.y);
    else
        screenRay *= ssrPixelSize.x / abs(screenRay.x);

    float texDepth;
    vec3 tracePos;

    clipPos += screenRay * GetScreenBayerValue();

    int i = 1;
    float alpha = 0.0;
    for (; i <= SSR_STEPS && alpha < 0.5; i++) {
        tracePos = clipPos + i*screenRay;

        if (abs(tracePos.x - clipPos.x) < ssrPixelSize.x*1.5
         && abs(tracePos.y - clipPos.y) < ssrPixelSize.y*1.5) continue;

        if (clamp(tracePos, vec3(0.0), vec3(1.0)) != tracePos) break;

        // if (tracePos.x <= 0.0 || tracePos.x >= 1.0
        //  || tracePos.y <= 0.0 || tracePos.y >= 1.0
        //  || tracePos.z <= 0.0 || tracePos.z >= 1.0) break;

        texDepth = textureLod(depthtex, tracePos.xy, 0).r;
        //if (texDepth > tracePos.z - EPSILON) continue;
        alpha = step(texDepth, tracePos.z - EPSILON);

        //float d = 0.8*i;// + EPSILON;
        //if (linearizeDepthFast(texDepth, near, far) > linearizeDepthFast(tracePos.z, near, far) - d) continue;

        //if (i > 1) alpha = 1.0;
        //alpha = 1.0;
    }

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        color = textureLod(BUFFER_HDR_PREVIOUS, tracePos.xy, lod).rgb;
        //vec2 mipTexSize = vec2(viewWidth, viewHeight) / exp2(lod + 1);
        //color = TextureLodLinearRGB(BUFFER_HDR_PREVIOUS, tracePos.xy, mipTexSize, lod);
    }

    return vec4(color, alpha);
}
