void ApplyLightning(out vec3 diffuse, out vec3 specular, const in vec3 albedo, const in float f0, const in int hcm, const in float scattering, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL) {
    vec3 lightOffset = lightningBoltPosition.xyz - viewPos;
    vec3 lightDir = normalize(lightOffset);
    float lightDist = length(lightPos);
    float NoL = dot(viewNormal, lightDir);
    float NoLm = max(NoL, 0.0);

    float attenuation = 1.0; // TODO

    if (attenuation < EPSILON || NoLm < EPSILON) return;

    vec3 halfDir = normalize(lightDir + viewDir);
    float LoHm = max(dot(lightDir, halfDir), 0.0);

    vec3 lightColor = vec3(100000.0);

    if (isEyeInWater == 1) {
        float viewDist = length(viewPos);
        vec3 extinctionInv = 1.0 - waterAbsorbColor;
        vec3 absorption = exp(-extinctionInv * (lightDist + viewDist));
        lightColor *= absorption;
    }

    vec3 F = GetFresnel(albedo, f0, hcm, LoHm, roughL);
    diffuse += GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL) * max(1.0 - F, 0.0) * lightColor;
    //diffuse = GetDiffuseBSDF(handDiffuse, albedo, scattering, NoVm, abs(NoL), LoHm, roughL);

    //if (NoLm < EPSILON) return;
    
    float NoHm = max(dot(viewNormal, halfDir), 0.0);
    specular += GetSpecularBRDF(F, NoVm, NoLm, NoHm, roughL) * lightColor;
}
