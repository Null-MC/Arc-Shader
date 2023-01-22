float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
    float diffuseAtt = saturate(0.0625*lightLevel - 0.08*lightDist);
    return pow3(diffuseAtt);
}

vec3 _ApplyHandLighting(const in vec3 albedo, const in vec3 lightPos, const in int lightLevel, const in int itemId) {
    float lightDist = length(lightPos);
    float attenuation = GetHandLightAttenuation(lightLevel, lightDist);
    if (attenuation < EPSILON) return vec3(0.0);

    vec3 handLightColor;

    if (itemId > 0 && itemId <= 5) {
        vec3 itemColor = itemLightColors[itemId-1];
        handLightColor = RGBToLinear(itemColor) * BlockLightLux * attenuation;
    }
    else
        handLightColor = attenuation * blockLightColor;

    return invPI * albedo * handLightColor;
}

vec3 ApplyHandLighting(const in vec3 albedo, const in vec3 viewPos) {
    vec3 diffuseMain = vec3(0.0);
    if (heldBlockLightValue > 0) {
        vec3 lightPosMain = handOffsetMain - viewPos;
        diffuseMain = _ApplyHandLighting(albedo, lightPosMain, heldBlockLightValue, heldItemId);
    }

    vec3 diffuseAlt = vec3(0.0);
    if (heldBlockLightValue2 > 0) {
        vec3 lightPosAlt = handOffsetAlt - viewPos;
        diffuseAlt = _ApplyHandLighting(albedo, lightPosAlt, heldBlockLightValue2, heldItemId2);
    }
    
    return diffuseMain + diffuseAlt;
}
