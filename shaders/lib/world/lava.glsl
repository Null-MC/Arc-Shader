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
    for (int i = 0; i < 9; i++) {
        float p = texture(TEX_CLOUD_NOISE, texPos).g;
        accum += p * weight;
        maxWeight += weight;

        texPos *= 1.6;
        weight *= 0.6;
    }

    return accum / maxWeight;
}

void ApplyLavaMaterial(inout PbrMaterial material, const in vec3 geoNormal, const in vec3 worldPos) {
    material.albedo = vec4(1.0);

    float time = frameTimeCounter / 3600.0;
    vec3 texPos = worldPos.xzy * vec3(0.025, 0.025, 0.100);
    texPos += vec3(0.05, 0.05, 1.00) * fract(time * 12.0);

    float pressure = LavaFBM(texPos);

    vec3 worldPosFinal = (gbufferModelView * vec4(worldPos, 1.0)).xyz;
    worldPosFinal += geoNormal * 0.2 * smoothstep(0.34, 0.58, 1.0 - pressure) - 0.6*pow(pressure, 0.6);
    //worldPosFinal = matTBN * worldPosFinal;
    vec3 dX = dFdx(worldPosFinal);
    vec3 dY = dFdy(worldPosFinal);

    //material.normal = vec3(0.0, 0.0, 1.0);
    if (dX != vec3(0.0) && dY != vec3(0.0)) {
        vec3 n = cross(dX, dY);
        if (n != vec3(0.0))
            material.normal = normalize(n);

        // vec2 nTex = fract(worldPos.xz) * 128.0;
        // nTex = floor(nTex + 0.5) / 128.0;
        // RandomizeNormal(material.normal, nTex, 0.8 * (1.0 - pressure2));
    }

    float t = min(pow(max(pressure - 0.16, 0.0) * 1.4, 10.0), 1.0);

    float temp = 1000.0 + 15000.0 * t;
    material.albedo.rgb = 0.002 + blackbody(temp) * t * 2.0;

    material.smoothness = 0.38 * pow(1.0 - t, 4);//pow(1.0 - pressure, 2.0);
    material.emission = saturate(3.0 * t);
    material.f0 = 0.05;
    material.hcm = -1;
}