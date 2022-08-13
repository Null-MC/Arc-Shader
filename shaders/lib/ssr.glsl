// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    localPos += cameraPosition - previousCameraPosition;
    vec3 viewPosPrev = (gbufferPreviousModelView * vec4(localPos, 1.0)).xyz;

    vec3 localReflectDir = mat3(gbufferModelViewInverse) * reflectDir;
    vec3 reflectDirPrev = mat3(gbufferPreviousModelView) * localReflectDir;

    vec3 clipPos = unproject(gbufferProjection * vec4(viewPosPrev, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPosPrev + reflectDirPrev, 1.0)) * 0.5 + 0.5;

    vec2 pixelSize = rcp(0.5 * vec2(viewWidth, viewHeight));

    vec3 screenRay = reflectClipPos - clipPos;
    if (screenRay.z <= 0.0) return vec4(0.0);

    if (abs(screenRay.y) > abs(screenRay.x))
        screenRay *= pixelSize.y / abs(screenRay.y);
    else
        screenRay *= pixelSize.x / abs(screenRay.x);

    float texDepth;
    vec3 tracePos;
    vec2 uv;

    int i = 1;
    float alpha = 0.0;
    for (; i <= SSR_STEPS && alpha < 0.5; i++) {
        tracePos = clipPos + i*screenRay;

        if (tracePos.x <= 0.0 || tracePos.x >= 1.0
         || tracePos.y <= 0.0 || tracePos.y >= 1.0
         || tracePos.z <= 0.0 || tracePos.z >= 1.0) break;

        if (abs(tracePos.x - clipPos.x) < pixelSize.x
         && abs(tracePos.y - clipPos.y) < pixelSize.y) continue;

        uv = tracePos.xy;

        #ifndef IS_OPTIFINE
            uv *= 0.5;
        #endif

        texDepth = textureLod(depthtex, uv, 0).r;
        if (texDepth >= tracePos.z) continue;

        //float d = 0.1 * i*i;
        //if (linearizeDepthFast(texDepth, near, far) + d > linearizeDepthFast(tracePos.z, near, far)) {
            //if (i > 1) alpha = 1.0;
            alpha = 1.0;
            break;
        //}
    }

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        uv = tracePos.xy;

        #ifndef IS_OPTIFINE
            uv *= 0.5;
        #endif

        color = textureLod(BUFFER_HDR_PREVIOUS, uv, lod).rgb;
        //vec2 mipTexSize = vec2(viewWidth, viewHeight) / exp2(lod + 1);
        //color = TextureLodLinearRGB(BUFFER_HDR_PREVIOUS, tracePos.xy, mipTexSize, lod);
    }

    return vec4(color, alpha);
}
