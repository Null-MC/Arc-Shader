float GetScaledSkyHeight(const in float worldY) {
    float scaleY = (cameraPosition.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL);
    return groundRadiusMM + saturate(scaleY) * (atmosphereRadiusMM - groundRadiusMM);
}

vec3 getValFromTLUT(const in sampler3D tex, const in vec3 pos, const in vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);
    vec3 uv = vec3(
        0.5 + 0.5*sunCosZenithAngle,
        (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM),
        wetness);
    
    return textureLod(tex, uv, 0).rgb;
}

vec3 getValFromMultiScattLUT(const in sampler3D tex, const in vec3 pos, const in vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);

    vec3 uv = vec3(
        0.5 + 0.5*sunCosZenithAngle,
        (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM),
        wetness);
    
    return textureLod(tex, uv, 0).rgb;
}

#if !defined RENDER_PREPARE && ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
    vec3 getValFromSkyLUT(const in float worldY, const in vec3 viewDir, const in float lod) {
        float height = (worldY - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL);        
        height = groundRadiusMM + saturate(height) * (atmosphereRadiusMM - groundRadiusMM);

        //vec3 sunDir = GetSunDir();

        // #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        //     vec3 up = vec3(0.0, 1.0, 0.0);//gbufferModelView[1].xyz;
        // #else
        //     vec3 up = normalize(upPosition);
        // #endif
        const vec3 up = vec3(0.0, 1.0, 0.0);

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
        
        return textureLod(BUFFER_SKY_LUT, uv, lod).rgb;
    }

    vec3 GetFancySkyLuminance(const in float worldY, const in vec3 viewDir, const in float lod) {
        return NightSkyLumen + getValFromSkyLUT(worldY, viewDir, lod) * 256000.0;
    }
#endif
