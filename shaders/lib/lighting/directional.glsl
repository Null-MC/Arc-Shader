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
        blockLightNew *= saturate(dot(geoViewNormal, texViewNormal));
    }

    blockLightNew = clamp(blockLightNew, 1.0/32.0, 31.0/32.0);
    blockLight = mix(blockLight, blockLightNew, DirectionalLightmapStrengthF);
}
