void RandomizeNormal(inout vec3 normal, const in vec2 texPos, const in float maxTheta) {
    vec3 randomNormal = hash32(texPos) * 2.0 - 1.0;
    randomNormal.z *= sign(randomNormal.z);
    normal = mix(normal, randomNormal, maxTheta);
    normal = normalize(normal);
}

float LavaFBM(vec3 texPos) {
    float accum = 0.0;
    float weight = 1.0;
    float maxWeight = 0.0;
    for (int i = 0; i < 8; i++) {
        float p = texture(TEX_CLOUD_NOISE, texPos).g;
        accum += p * weight;
        maxWeight += weight;

        texPos *= 1.6;
        weight *= 0.7;
    }

    return accum / maxWeight;
}

void ApplyLavaMaterial(inout PbrMaterial material, const in vec3 worldPos) {
    material.albedo = vec4(1.0);

    float time = frameTimeCounter / 360.0;
    vec3 texPos = worldPos.xzy * vec3(0.025, 0.025, 0.100) + vec3(0.0, 0.0, fract(-time));

    float pressure = LavaFBM(texPos);

    //float pressure = 1.0 - (LavaWaveletNoise(worldPos.xz, time, 0.82) * 0.5 + 0.5);
    float pressure2 = pow2(pressure);
    float pressure4 = pow2(pressure2);

    float temp = 1000.0 + 15000.0 * pow(pressure, 10.0);

    vec3 worldPosFinal = worldPos.xzy;
    worldPosFinal.z += 0.4 * smoothstep(0.36, 0.56, 1.0 - pressure) - 0.3*pressure;
    vec3 dX = dFdx(worldPosFinal);
    vec3 dY = dFdy(worldPosFinal);

    material.normal = vec3(0.0, 0.0, 1.0);
    if (dX != vec3(0.0) && dY != vec3(0.0)) {
        vec3 n = cross(dY, dX);
        if (n != vec3(0.0))
            material.normal = normalize(n);

        // vec2 nTex = fract(worldPos.xz) * 128.0;
        // nTex = floor(nTex + 0.5) / 128.0;
        // RandomizeNormal(material.normal, nTex, 0.8 * (1.0 - pressure2));
    }

    material.albedo.rgb = 0.002 + blackbody(temp) * pow(pressure, 10.0) * 2.0;
    material.smoothness = 0.56 * pow(1.0 - pressure, 2.0);
    material.emission = saturate(3.0 * pressure4);
    material.f0 = 0.4;
}