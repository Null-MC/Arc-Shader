// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    vec3 clipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPos + reflectDir, 1.0)) * 0.5 + 0.5;

    vec3 screenRay = reflectClipPos - clipPos;
    if (abs(screenRay.y) > abs(screenRay.x)) {
        screenRay *= (1.0 / (0.5*viewHeight)) / abs(screenRay.y);
    }
    else {
        screenRay *= (1.0 / (0.5*viewWidth)) / abs(screenRay.x);
    }

    float texDepth;
    vec3 tracePos;

    int i = 1;
    float alpha = 0.0;
    for (; i <= SSR_STEPS && alpha < 0.5; i++) {
        tracePos = clipPos + i*screenRay;

        if (tracePos.x < 0.0 || tracePos.x > 1.0
         || tracePos.y < 0.0 || tracePos.y > 1.0
         || tracePos.z < 0.0 || tracePos.z > 1.0) break;

        texDepth = textureLod(depthtex, tracePos.xy, 0).r;

        float d = 0.1 * i;
        if (texDepth < tracePos.z - EPSILON) {// && linearizeDepth(texDepth * 2.0 - 1.0, near, far) + d > linearizeDepth(tracePos.z * 2.0 - 1.0, near, far)) {
            if (i > 1) alpha = 1.0;
            //alpha = 1.0;
            break;
        }
    }

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        // Previous frame reprojection from Chocapic13
        vec3 clip2 = vec3(tracePos.xy, texDepth) * 2.0 - 1.0;
        vec3 viewPosPrev = unproject(gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clip2, 1.0)));
        vec3 previousPosition = viewPosPrev + cameraPosition - previousCameraPosition;
        vec3 finalViewPos = unproject(gbufferPreviousProjection * (gbufferPreviousModelView * vec4(previousPosition, 1.0))) * 0.5 + 0.5;
        tracePos.xy = finalViewPos.xy;

        #ifndef IS_OPTIFINE
            tracePos.xy *= 0.5;
        #endif

        //color = textureLod(BUFFER_HDR_PREVIOUS, tracePos.xy, lod).rgb;
        vec2 mipTexSize = vec2(viewWidth, viewHeight) / exp2(lod + 1);
        color = TextureLodLinearRGB(BUFFER_HDR_PREVIOUS, tracePos.xy, mipTexSize, lod);
    }

    return vec4(color, alpha);
}
