// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    vec3 clipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPos + reflectDir, 1.0)) * 0.5 + 0.5;

    vec2 pixelSize = rcp(0.5 * vec2(viewWidth, viewHeight));

    vec3 screenRay = reflectClipPos - clipPos;
    if (screenRay.z <= 0.0) return vec4(0.0);

    if (abs(screenRay.y) > abs(screenRay.x))
        screenRay *= pixelSize.y / abs(screenRay.y);
    else
        screenRay *= pixelSize.x / abs(screenRay.x);

    float texDepth;
    vec3 tracePos;

    int i = 1;
    float alpha = 0.0;
    for (; i <= SSR_STEPS && alpha < 0.5; i++) {
        tracePos = clipPos + i*screenRay;

        if (abs(tracePos.x - clipPos.x) < pixelSize.x
         && abs(tracePos.y - clipPos.y) < pixelSize.y) continue;

        if (tracePos.x <= 0.0 || tracePos.x >= 1.0
         || tracePos.y <= 0.0 || tracePos.y >= 1.0
         || tracePos.z <= 0.0 || tracePos.z >= 1.0) break;

        texDepth = textureLod(depthtex, tracePos.xy, 0).r;
        if (texDepth >= tracePos.z) continue;

        float d = 0.2 + 0.06 * i;
        if (linearizeDepthFast(tracePos.z, near, far) < linearizeDepthFast(texDepth, near, far) + d) continue;

        //if (i > 1) alpha = 1.0;
        alpha = 1.0;
    }

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        color = textureLod(BUFFER_HDR_PREVIOUS, tracePos.xy, lod).rgb;
        //vec2 mipTexSize = vec2(viewWidth, viewHeight) / exp2(lod + 1);
        //color = TextureLodLinearRGB(BUFFER_HDR_PREVIOUS, tracePos.xy, mipTexSize, lod);
    }

    return vec4(color, alpha);
}
