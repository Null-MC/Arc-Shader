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

#define LAVA_SPEED 24.0 // [12 24]

void ApplyLavaMaterial(inout PbrMaterial material, const in vec3 geoViewNormal, const in vec3 worldPos, const in vec3 viewPos) {
    material.albedo = vec4(1.0);
    material.normal = geoViewNormal;

    float time = frameTimeCounter / 3600.0;
    vec3 texPos = worldPos.xzy * vec3(0.025, 0.025, 0.070);
    texPos += vec3(0.05, 0.05, 1.00) * fract(time * LAVA_SPEED);

    vec3 upViewDir = normalize(upPosition);
    float NoU = abs(dot(geoViewNormal, upViewDir));

    float pressure = LavaFBM(texPos);
    float coolF = 0.16 * NoU;
    float heatF = 1.0 + 0.4 * NoU;
    float heatP = 6.0 + 4.0 * NoU;
    float t = min(pow(max(pressure - coolF, 0.0) * heatF, heatP), 1.0);

    float temp = 1000.0 + 15000.0 * t;
    material.albedo.rgb = 0.002 + blackbody(temp) * t * 2.0;
    material.smoothness = 0.28 * pow(1.0 - t, 2.0);
    material.emission = saturate(3.0 * t);
    material.f0 = 0.06 - 0.02 * t;
    material.hcm = -1;

    float heightMax = 0.8 - 0.22 * NoU;
    float height = smoothstep(0.34, heightMax, 1.0 - pressure) - pow(pressure, 0.7);
    vec3 viewPosFinal = viewPos + geoViewNormal * 0.2 * height;
    vec3 dX = dFdx(viewPosFinal);
    vec3 dY = dFdy(viewPosFinal);

    if (dX != vec3(0.0) && dY != vec3(0.0)) {
        vec3 n = cross(dX, dY);
        if (n != vec3(0.0))
            material.normal = normalize(n);

        // vec2 nTex = fract(worldPos.xz) * 128.0;
        // nTex = floor(nTex + 0.5) / 128.0;
        // RandomizeNormal(material.normal, nTex, 0.8 * (1.0 - pressure2));
    }
}
