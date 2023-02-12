void ApplyDirectionalLightmap(inout float blockLight, const in vec3 viewPos, const in vec3 geoViewNormal, const in vec3 texViewNormal) {
    vec3 dFdViewposX = dFdx(viewPos);
    vec3 dFdViewposY = dFdy(viewPos);

    vec2 dFdTorch = vec2(dFdx(blockLight), dFdy(blockLight));

    float blockLightNew = blockLight;
    if (dot(dFdTorch, dFdTorch) > 1.0e-10) {
        vec3 torchLightViewDir = normalize(dFdViewposX * dFdTorch.x + dFdViewposY * dFdTorch.y);
        blockLightNew *= saturate(dot(torchLightViewDir, texViewNormal) + 0.6) * 0.8 + 0.2;
    }
    else {
        //vec3 torchLightDir = matTBN * vec3(0.0, 0.0, 1.0);
        //vec3 torchLightViewDir = geoViewNormal;
        blockLightNew *= saturate(dot(geoViewNormal, texViewNormal));
    }

    blockLightNew = clamp(blockLightNew, 1.0/32.0, 31.0/32.0);
    blockLight = mix(blockLight, blockLightNew, DirectionalLightmapStrengthF);

    //vec2 dFdSky = vec2(dFdx(lmcoord.g), dFdy(lmcoord.g));
    // vec3 skyLightDir = dFdViewposX * dFdSky.x + dFdViewposY * dFdSky.y;
    // if(length(dFdSky) > 1e-6) {
    //     lightmapOut.g *= clamp(dot(normalize(skyLightDir), geoViewNormal) + 0.8, 0.0, 1.0) * 0.8 + 0.2;
    // }
    // else {
    //     lightmapOut.g *= clamp(dot(vec3(0.0, 1.0, 0.0), texViewNormal) + 0.8, 0.0, 1.0) * 0.4 + 0.6;
    // }


    // vec3 lightPos = vec3(viewPos, blockLight);
    // //vec3 lmDXY = vec3(dFdx(blockLight), dFdy(blockLight), 0.0);

    // vec3 light_tangent = normalize(dFdx(lightPos));
    // vec3 light_binormal = normalize(dFdy(lightPos));

    // if (all(lessThan(abs(light_tangent) + abs(light_binormal), vec3(EPSILON)))) {
    //     //blockLight = blockLight*blockLight;
    //     return;
    // }

    // vec3 light_normal = cross(light_tangent, light_binormal);
    // //mat3 matLMTBN = mat3(tangent, binormal, normal);

    // //vec3 lmDir = lmDXY * matLMTBN;
    // float lmDot = max(dot(texViewNormal, light_normal), 0.0);

    // //float light = blockLight * lmDot;
    // float strength = DIRECTIONAL_LIGHTMAP_STRENGTH * 0.01;
    // blockLight *= mix(1.0, lmDot, strength);
}
