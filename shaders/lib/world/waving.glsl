vec3 hash33(in vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

vec3 noise(vec3 p) {
    vec3 f = fract(p);
    p = floor(p);
    return mix(
        mix(
            mix(
                hash33(p + vec3(0, 0, 0)),
                hash33(p + vec3(0, 0, 1)),
                f.z
            ),
            mix(
                hash33(p + vec3(0, 1, 0)),
                hash33(p + vec3(0, 1, 1)),
                f.z
            ),
            f.y
        ),
        mix(
            mix(
                hash33(p + vec3(1, 0, 0)),
                hash33(p + vec3(1, 0, 1)),
                f.z
            ),
            mix(
                hash33(p + vec3(1, 1, 0)),
                hash33(p + vec3(1, 1, 1)),
                f.z
            ),
            f.y
        ),
        f.x
    );
}

vec3 fbm(vec3 pos) {
    vec3 val = vec3(0);
    float weight = 0.5;
    float totalWeight = 0.0;
    float frequency = 1000.0;
    for (int i = 0; i < 8; i++) {
        val += noise(pos * frequency) * weight;
        totalWeight += weight;
        weight /= 2.0;
        frequency *= 2.0;
    }

    return val / totalWeight;
}

vec3 GetWavingOffset() {
    float range = (mc_Entity.x == 10002.0 || mc_Entity.x == 10004.0) ? 0.01 : 0.06;

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        vec3 worldPos = floor(vaPosition.xyz + chunkOffset + cameraPosition + 0.5);
    #else
        vec3 worldPos = gl_Vertex.xyz + at_midBlock / 64.0;
        #ifndef RENDER_SHADOW
            worldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * vec4(worldPos, 1.0))).xyz;
        #else
            worldPos = (shadowModelViewInverse * (gl_ModelViewMatrix * vec4(worldPos, 1.0))).xyz;
        #endif
        worldPos = floor(worldPos + cameraPosition + 0.5);
    #endif

    #ifdef ANIM_USE_WORLDTIME
        float time = worldTime / 24.0;
    #else
        float time = frameTimeCounter;
    #endif

	vec3 hash = mod(fbm(worldPos) * 2.0 * PI + time, 2.0 * PI);
	vec3 offset = sin(hash) * range;

    // Prevent waving for blocks with the base attached to ground.
    if (mc_Entity.x >= 10003.0 && mc_Entity.x <= 10004.0) {
        float baseOffset = -at_midBlock.y / 64.0 + 0.5;
        offset *= clamp(baseOffset, 0.0, 1.0);
    }

    return offset;
}
