float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
    float diffuseAtt = max(0.0625*lightLevel - 0.08*lightDist, 0.0);
    return pow5(diffuseAtt) * 10.0;
}

vec3 _ApplyHandLighting(const in vec3 albedo, const in vec3 lightPos, const in int lightLevel) {
    float lightDist = length(lightPos);
    float attenuation = GetHandLightAttenuation(lightLevel, lightDist);
    if (attenuation < EPSILON) return vec3(0.0);

    return albedo * blockLightColor * attenuation;
}

vec3 ApplyHandLighting(const in vec3 albedo, const in vec3 viewPos) {
    vec3 diffuseMain = vec3(0.0);
    if (heldBlockLightValue > 0) {
        vec3 lightPosMain = handOffsetMain - viewPos;
        diffuseMain = _ApplyHandLighting(albedo, lightPosMain, heldBlockLightValue);
    }

    vec3 diffuseAlt = vec3(0.0);
    if (heldBlockLightValue2 > 0) {
        vec3 lightPosAlt = handOffsetAlt - viewPos;
        diffuseAlt = _ApplyHandLighting(albedo, lightPosAlt, heldBlockLightValue2);
    }
    
    return diffuseMain + diffuseAlt;
}