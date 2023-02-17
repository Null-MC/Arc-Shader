float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
    //return max(lightLevel - lightDist, 0.0) / 15.0;
    float diffuseAtt = saturate(0.08*lightLevel - 0.08*lightDist);
    return pow(diffuseAtt, 3);
}

void _ApplyHandLighting(out vec3 diffuse, out vec3 specular, const in vec3 albedo, const in float f0, const in int hcm, const in float scattering, const in vec3 lightPos, const in int lightLevel, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL, const in int itemId) {
    float lightDist = length(lightPos);
    float attenuation = GetHandLightAttenuation(lightLevel, lightDist);
    
    if (lightDist < EPSILON || attenuation < EPSILON) {
        diffuse = vec3(0.0);
        specular = vec3(0.0);
        return;
    }

    vec3 lightDir = normalize(lightPos);

    float NoL = dot(viewNormal, lightDir);
    float NoLm = max(NoL, 0.0);

    vec3 halfDir = normalize(lightDir + viewDir);
    float LoHm = max(dot(lightDir, halfDir), 0.0);

    vec3 handLightColor;

    if (itemId > 0 && itemId <= 5) {
        vec3 itemColor = itemLightColors[itemId-1];
        handLightColor = RGBToLinear(itemColor);
    }
    else
        handLightColor = blockLightColor;

    handLightColor *= BlockLightLux * attenuation;

    #ifdef WORLD_WATER_ENABLED
        if (isEyeInWater == 1) {
            vec3 extinctionInv = 1.0 - waterAbsorbColor;
            handLightColor *= exp(-extinctionInv * lightDist);
        }
    #endif
    
    vec3 F = GetFresnel(albedo, f0, hcm, LoHm, roughL);
    vec3 handDiffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL) * max(1.0 - F, 0.0);
    diffuse = handDiffuse * handLightColor;//GetDiffuseBSDF(handDiffuse, albedo, scattering, NoVm, abs(NoL), LoHm, roughL) * handLightColor;

    if (NoLm < EPSILON) {
        specular = vec3(0.0);
        return;
    }
    
    float NoHm = max(dot(viewNormal, halfDir), 0.0);
    specular = GetSpecularBRDF(F, NoVm, NoLm, NoHm, roughL) * handLightColor;
}

void ApplyHandLighting(out vec3 diffuse, out vec3 specular, const in vec3 albedo, const in float f0, const in int hcm, const in float scattering, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL) {
    vec3 diffuseMain = vec3(0.0);
    vec3 specularMain = vec3(0.0);
    if (heldBlockLightValue > 0) {
        vec3 lightPosMain = handOffsetMain - viewPos;
        _ApplyHandLighting(diffuseMain, specularMain, albedo, f0, hcm, scattering, lightPosMain, heldBlockLightValue, viewNormal, viewPos, viewDir, NoVm, roughL, heldItemId);
    }

    vec3 diffuseAlt = vec3(0.0);
    vec3 specularAlt = vec3(0.0);
    if (heldBlockLightValue2 > 0) {
        vec3 lightPosAlt = handOffsetAlt - viewPos;
        _ApplyHandLighting(diffuseAlt, specularAlt, albedo, f0, hcm, scattering, lightPosAlt, heldBlockLightValue2, viewNormal, viewPos, viewDir, NoVm, roughL, heldItemId2);
    }
    
    diffuse = diffuseMain + diffuseAlt;
    specular = specularMain + specularAlt;
}
