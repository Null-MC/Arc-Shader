// === This is originally from BSL ===
// Huge thanks to Capt Tatsu for allowing me to borrow it
// until my SSR implementation is working.

// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    const float maxf = 4.0;
    const float stp = 1.0;
    const float ref = 0.1;
    const float inc = 2.0;

    vec3 vector = stp * reflectDir;
    vec3 traceVector = vector;
    vec3 traceUV = vec3(0.0);
    float alpha = 0.0;

    vec3 startViewPos = viewPos + vector;

    int sr = 0;
    for (int i = 1; i <= 30 && alpha < 0.5; i++) {
        vec3 traceViewPos = startViewPos + traceVector;
        traceUV = unproject(gbufferProjection * vec4(traceViewPos, 1.0)) * 0.5 + 0.5;
        if (traceUV.x < 0.0 || traceUV.x > 1.0 || traceUV.y < 0.0 || traceUV.y > 1.0) break;

        vec3 clipPos = vec3(traceUV.xy, textureLod(depthtex, traceUV.xy, 0).r) * 2.0 - 1.0;
        vec3 texViewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));

        float err = length(traceViewPos - texViewPos);
        if (err < pow(length(vector) * pow(length(traceVector), 0.11), 1.1) * 1.2) {
            alpha = step(maxf, sr++);
            traceVector -= vector;
            vector *= ref;
        }

        vector *= inc;
        traceVector += vector;
    }

    alpha *= step(0.001, length(traceVector));

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        // Previous frame reprojection from Chocapic13
        vec3 viewPosPrev = unproject(gbufferModelViewInverse * (gbufferProjectionInverse * vec4(traceUV * 2.0 - 1.0, 1.0)));
        vec3 previousPosition = viewPosPrev + cameraPosition - previousCameraPosition;
        vec3 finalViewPos = unproject(gbufferPreviousProjection * (gbufferPreviousModelView * vec4(previousPosition, 1.0))) * 0.5 + 0.5;
        traceUV.xy = finalViewPos.xy;

        #ifndef IS_OPTIFINE
            traceUV.xy *= 0.5;
        #endif

        color = textureLod(BUFFER_HDR_PREVIOUS, traceUV.xy, lod).rgb;
    }

    return vec4(color, alpha);
}
