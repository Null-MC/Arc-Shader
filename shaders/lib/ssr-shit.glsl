// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in float roughness) {
    vec3 clipPos = unproject(gbufferProjection * vec4(viewPos, 1.0)) * 0.5 + 0.5;
    vec3 reflectClipPos = unproject(gbufferProjection * vec4(viewPos + reflectDir, 1.0)) * 0.5 + 0.5;
    vec2 screenReflectDir = normalize(reflectClipPos.xy - clipPos.xy);//reflectDir.xy;

    vec2 traceStep;
    if (abs(screenReflectDir.y) > abs(screenReflectDir.x)) {
        traceStep = vec2(screenReflectDir.x / abs(screenReflectDir.y), sign(screenReflectDir.y));
    }
    else {
        traceStep = vec2(sign(screenReflectDir.x), screenReflectDir.y / abs(screenReflectDir.x));
    }

    traceStep /= vec2(viewWidth, viewHeight);

    //vec3 traceViewPosLast = viewPos;
    //return vec4(10000.0, 0.0, 0.0, 1.0);

    int i = 1;
    float alpha = 0.0;
    float texDepth = 0.0;
    vec2 traceUV = clipPos.xy;
    for (; i <= 64 && alpha < 0.5; i++) {
        //float traceViewDepth = viewPos.z ;
        //float traceDepth = delinearizeDepthFast(traceViewDepth, near, far);

        traceUV = clipPos.xy + i * traceStep;
        texDepth = textureLod(depthtex, traceUV, 0).r;

        vec3 texClipPos = vec3(traceUV, texDepth) * 2.0 - 1.0;
        vec3 texViewPos = unproject(gbufferProjectionInverse * vec4(texClipPos, 1.0));

        vec2 xyDiff = texViewPos.xy - viewPos.xy;
        float traceViewZ = viewPos.z + reflectDir.z * length(xyDiff);

        //alpha = step(texViewPos.z, traceViewZ);
        if (traceViewZ > texViewPos.z + 0.01) {
            //return vec4(0.0, 1.0, 0.0, 1.0);
            alpha = 1.0;
            break;
        }
    }

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        int prevI = max(i - 1, 0);
        traceUV = clipPos.xy + prevI * traceStep;
        color = textureLod(BUFFER_HDR_PREVIOUS, traceUV, 0).rgb;
    }

    return vec4(color, alpha);
}
