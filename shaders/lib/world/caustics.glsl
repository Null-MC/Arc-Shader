vec3 GetWaterCaustics(const in vec3 worldPos, const in vec3 localLightDir, const in float waterDepth) {
    vec3 waterWorldPos = worldPos + localLightDir * waterDepth;
    vec3 texPos = waterWorldPos.xzy * vec3(0.02, 0.02, 0.08);
    float time = frameTimeCounter / 3600.0 * 60.0;

    float caustics = 0.0;
    for (int i = 0; i < 3; i++) {
        vec3 t1 = texPos + time;
        float texNoise1 = texture(TEX_CLOUD_NOISE, t1).r;
        
        vec3 t2 = texPos * 0.9 - time - 0.12 * texNoise1;
        float texNoise2 = texture(TEX_CLOUD_NOISE, t2).g;

        vec3 t3 = texPos * 1.1 + time + 0.12 * texNoise1;
        float texNoise3 = texture(TEX_CLOUD_NOISE, t3).g;

        caustics += pow(max(texNoise2, texNoise3), 14.0);
        texPos.xy = texPos.xy * 1.8 + 0.2;
    }

    vec3 waterExtinctionInv = 1.0 - waterAbsorbColor;
    vec3 ext = exp(-waterDepth * waterExtinctionInv);

    return caustics * ext;
}
