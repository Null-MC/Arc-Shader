// === This is originally from BSL ===
// Huge thanks to Capt Tatsu for allowing me to borrow it
// until my SSR implementation is working.

// returns: rgb=color  a=attenuation
vec4 GetReflectColor(const in sampler2D depthtex, const in vec3 viewPos, const in vec3 reflectDir, const in int lod) {
    const float maxf = 4.0;
    const float stp = 0.1;
    const float ref = 0.8;
    const float inc = 1.2;

    vec3 vector = stp * reflectDir;
    vec3 traceVector = vector;
    vec3 traceUV = vec3(0.0);
    float alpha = 0.0;

    int sr = 0;
    for (int i = 1; i <= 64 && alpha < 0.5; i++) {
        vec3 tracePos = viewPos + traceVector;
        traceUV = unproject(gbufferProjection * vec4(tracePos, 1.0)) * 0.5 + 0.5;
        if (traceUV.x < -0.05 || traceUV.x > 1.05 || traceUV.y < -0.05 || traceUV.y > 1.05) break;

        vec3 rfragpos = vec3(traceUV.xy, textureLod(depthtex, traceUV.xy, 0).r);
        rfragpos = unproject(gbufferProjectionInverse * vec4(rfragpos * 2.0 - 1.0, 1.0));

        float err = length(tracePos - rfragpos);
        if (err < pow(length(vector) * pow(length(traceVector), 0.11), 1.1) * 1.2) {
            alpha = step(maxf, sr++);
            traceVector -= vector;
            vector *= ref;
        }

        vector *= inc;
        traceVector += vector;
    }

    // Previous frame reprojection from Chocapic13
    vec4 viewPosPrev = gbufferProjectionInverse * vec4(traceUV * 2.0 - 1.0, 1.0);
    viewPosPrev /= viewPosPrev.w;
    
    viewPosPrev = gbufferModelViewInverse * viewPosPrev;

    vec4 previousPosition = viewPosPrev + vec4(cameraPosition - previousCameraPosition, 0.0);
    previousPosition = gbufferPreviousModelView * previousPosition;
    previousPosition = gbufferPreviousProjection * previousPosition;
    traceUV.xy = previousPosition.xy / previousPosition.w * 0.5 + 0.5;

    vec3 color = vec3(0.0);
    if (alpha > 0.5) {
        #ifndef IS_OPTIFINE
            traceUV.xy *= 0.5;
        #endif

        color = textureLod(BUFFER_HDR_PREVIOUS, traceUV.xy, lod).rgb;
    }

    return vec4(color, alpha);
}
