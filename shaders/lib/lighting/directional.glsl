void ApplyDirectionalLightmap(inout float blockLight, const in vec3 texViewNormal) {
    vec2 lmDXY = vec2(dFdx(blockLight), dFdy(blockLight)) * 16.0;

    if (dot(lmDXY, lmDXY) <= EPSILON) {
        blockLight = blockLight*blockLight;
        return;
    }

    mat3 matLMTBN;
    matLMTBN[0] = normalize(dFdx(viewPos));
    matLMTBN[1] = normalize(dFdy(viewPos));
    matLMTBN[2] = cross(matLMTBN[0], matLMTBN[1]);

    vec3 lmDir = normalize(vec3(lmDXY.x * matLMTBN[0] + 0.001 * matLMTBN[2] + lmDXY.y * matLMTBN[1]));
    float lmDot = max(dot(texViewNormal, lmDir), 0.0);
    blockLight *= 1.0 - (1.0 - pow2(blockLight)) * (1.0 - lmDot);
}
