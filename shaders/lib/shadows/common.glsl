#if defined IRIS_FEATURE_SSBO && !defined RENDER_BEGIN
    layout(std430, binding = 0) readonly buffer csmData {
        mat4 shadowModelViewEx;         // 64

        // CSM
        float cascadeSize[4];           // 16
        vec2 shadowProjectionSize[4];   // 32
        vec2 shadowProjectionPos[4];    // 32
        mat4 cascadeProjection[4];      // 256
    };
#endif

vec3 GetShadowIntervalOffset() {
    return fract(cameraPosition / shadowIntervalSize) * shadowIntervalSize;
}

mat4 BuildShadowViewMatrix(const in vec3 localLightDir) {
    const vec3 worldUp = vec3(0.0, 1.0, 0.0);

    vec3 zaxis = localLightDir;    
    vec3 xaxis = normalize(cross(worldUp, zaxis));
    vec3 yaxis = cross(zaxis, xaxis);

    mat4 shadowModelViewEx = shadowModelView;
    shadowModelViewEx[0].xyz = vec3(xaxis.x, yaxis.x, zaxis.x);
    shadowModelViewEx[1].xyz = vec3(xaxis.y, yaxis.y, zaxis.y);
    shadowModelViewEx[2].xyz = vec3(xaxis.z, yaxis.z, zaxis.z);
    shadowModelViewEx[3].xyz = vec3(0.0);

    vec3 intervalOffset = GetShadowIntervalOffset();
    mat4 translation = BuildTranslationMatrix(intervalOffset);

    return translation * shadowModelViewEx;
}

mat4 BuildShadowViewMatrix() {
    vec3 localLightDir = GetShadowLightLocalDir();
    return BuildShadowViewMatrix(localLightDir);
}
