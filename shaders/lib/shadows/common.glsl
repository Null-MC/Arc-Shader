vec3 GetShadowIntervalOffset() {
    return fract(cameraPosition / shadowIntervalSize) * shadowIntervalSize;
}

mat4 BuildShadowViewMatrix(const in vec3 localLightDir) {
    //#ifndef WORLD_END
    //    return shadowModelView;
    //#else
        const vec3 worldUp = vec3(1.0, 0.0, 0.0);

        vec3 zaxis = localLightDir;
        vec3 xaxis = normalize(cross(worldUp, zaxis));
        vec3 yaxis = cross(zaxis, xaxis);

        mat4 shadowModelViewEx = mat4(1.0);
        shadowModelViewEx[0].xyz = vec3(xaxis.x, yaxis.x, zaxis.x);
        shadowModelViewEx[1].xyz = vec3(xaxis.y, yaxis.y, zaxis.y);
        shadowModelViewEx[2].xyz = vec3(xaxis.z, yaxis.z, zaxis.z);

        vec3 intervalOffset = GetShadowIntervalOffset();
        mat4 translation = BuildTranslationMatrix(intervalOffset);

        return shadowModelViewEx * translation;
    //#endif
}

mat4 BuildShadowViewMatrix() {
    vec3 localLightDir = GetShadowLightLocalDir();
    return BuildShadowViewMatrix(localLightDir);
}

mat4 BuildShadowProjectionMatrix() {
    return BuildOrthoProjectionMatrix(shadowDistance, shadowDistance, -far, far);
}
