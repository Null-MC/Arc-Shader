void ApplyDirectionalLightmap(inout float blockLight, const in vec3 texViewNormal) {
    vec3 lightPos = vec3(viewPos, blockLight);
    //vec3 lmDXY = vec3(dFdx(blockLight), dFdy(blockLight), 0.0);

    vec3 light_tangent = normalize(dFdx(lightPos));
    vec3 light_binormal = normalize(dFdy(lightPos));

    if (all(lessThan(abs(tangent) + abs(binormal), vec3(EPSILON)))) {
        //blockLight = blockLight*blockLight;
        return;
    }

    vec3 light_normal = cross(light_tangent, light_binormal);
    //mat3 matLMTBN = mat3(tangent, binormal, normal);

    //vec3 lmDir = lmDXY * matLMTBN;
    float lmDot = max(dot(texViewNormal, light_normal), 0.0);

    //float light = blockLight * lmDot;
    float strength = DIRECTIONAL_LIGHTMAP_STRENGTH * 0.01;
    blockLight *= mix(1.0, lmDot, strength);
}
