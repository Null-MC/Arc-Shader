// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    vec3 clipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPos + reflectDir, 1.0)) * 0.5 + 0.5;
    //vec2 screenReflectDir = normalize(reflectClipPos.xy - clipPos.xy);//reflectDir.xy;
    vec3 screenReflectDir = reflectClipPos - clipPos;//reflectDir.xy;
    screenReflectDir *= 0.1;
    //float stepZ = reflectClipPos.z - clipPos.z;

    //vec2 traceStep;
    //if (abs(screenReflectDir.y) > abs(screenReflectDir.x)) {
    //    traceStep = vec2(screenReflectDir.x / abs(screenReflectDir.y), sign(screenReflectDir.y));
    //}
    //else {
    //    traceStep = vec2(sign(screenReflectDir.x), screenReflectDir.y / abs(screenReflectDir.x));
    //}

    //traceStep /= vec2(viewWidth, viewHeight);

    int i = 1;
    float alpha = 0.0;
    float texDepth = 1.0;
    vec2 traceUV;// = clipPos.xy;
    for (; i <= 256 && alpha < 0.5; i++) {
        traceUV = clipPos.xy + i * screenReflectDir.xy;
        float traceZ = clipPos.z + i*screenReflectDir.z;

        if (traceUV.x < 0.0 || traceUV.x > 1.0
         || traceUV.y < 0.0 || traceUV.y > 1.0
         || traceZ < 0.0 || traceZ > 1.0) break;

        texDepth = textureLod(depthtex, traceUV, 0).r;

        float d = 0.2 * i;
        if (texDepth < traceZ && linearizeDepth(texDepth * 2.0 - 1.0, near, far) + d > linearizeDepth(traceZ * 2.0 - 1.0, near, far)) {
            if (i > 1) alpha = 1.0;
            break;
        }
    }

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        //int prevI = i;//max(i - 1, 0);
        traceUV = clipPos.xy + i * screenReflectDir.xy;

        // Previous frame reprojection from Chocapic13
        vec3 clip2 = vec3(traceUV, texDepth) * 2.0 - 1.0;
        vec3 viewPosPrev = unproject(gbufferModelViewInverse * (gbufferProjectionInverse * vec4(clip2, 1.0)));
        vec3 previousPosition = viewPosPrev + cameraPosition - previousCameraPosition;
        vec3 finalViewPos = unproject(gbufferPreviousProjection * (gbufferPreviousModelView * vec4(previousPosition, 1.0))) * 0.5 + 0.5;
        traceUV = finalViewPos.xy;

        #ifndef IS_OPTIFINE
            traceUV *= 0.5;
        #endif

        //color = textureLod(BUFFER_HDR_PREVIOUS, traceUV, lod).rgb;
        vec2 mipTexSize = vec2(viewWidth, viewHeight) / exp2(lod + 1);
        color = TextureLodLinearRGB(BUFFER_HDR_PREVIOUS, traceUV, mipTexSize, lod);
    }

    return vec4(color, alpha);
}
