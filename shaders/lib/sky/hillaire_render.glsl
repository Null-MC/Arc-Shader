// float GetScaledSkyHeight(const in float worldY) {
//     float scaleY = (cameraPosition.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
//     return groundRadiusMM + scaleY * (atmosphereRadiusMM - groundRadiusMM);
// }

vec3 getValFromSkyLUT(const in float worldY, const in vec3 viewDir, const in float lod) {
    float height = (worldY - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL);

    // WARN: This is a temp fix cause idk what's going wrong when camera is under sea level!
    height = max(height, 0.0);
    
    height = groundRadiusMM + height * (atmosphereRadiusMM - groundRadiusMM);

    vec3 sunDir = GetSunDir();

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        vec3 up = gbufferModelView[1].xyz;
    #else
        vec3 up = normalize(upPosition);
    #endif

    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height);
    float altitudeAngle = horizonAngle - acos(dot(viewDir, up)); // Between -PI/2 and PI/2
    float azimuthAngle; // Between 0 and 2*PI

    if (abs(altitudeAngle) > (0.5*PI - 0.0001)) {
        // Looking nearly straight up or down.
        azimuthAngle = 0.0;
    } else {
        vec3 projectedDir = normalize(viewDir - up*(dot(viewDir, up)));
        float sinTheta = dot(projectedDir, gbufferModelView[0].xyz);
        float cosTheta = dot(projectedDir, gbufferModelView[2].xyz);
        azimuthAngle = atan(sinTheta, cosTheta) + PI;
    }
    
    // Non-linear mapping of altitude angle. See Section 5.3 of the paper.
    float v = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0 / PI);
    vec2 uv = vec2(azimuthAngle / (2.0*PI), v);
    
    return textureLod(BUFFER_SKY_LUT, uv, lod).rgb * 16000.0;
}

vec3 GetFancySkyLuminance(const in float worldY, const in vec3 viewDir, const in float lod) {
    return NightSkyLumen + getValFromSkyLUT(worldY, viewDir, lod);
}

vec3 GetFancySkyLuminance(const in vec3 viewDir, const in float lod) {
    return NightSkyLumen + getValFromSkyLUT(cameraPosition.y, viewDir, lod);
}
