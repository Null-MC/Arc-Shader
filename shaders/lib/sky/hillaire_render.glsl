vec3 getValFromTLUT(const in sampler3D tex, const in vec3 pos, const in vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);
    vec3 uv = vec3(
        0.5 + 0.5*sunCosZenithAngle,
        (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM),
        rainStrength);
    
    return textureLod(tex, uv, 0).rgb;
}

vec3 getValFromMultiScattLUT(const in sampler3D tex, const in vec3 pos, const in vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);

    vec3 uv = vec3(
        0.5 + 0.5*sunCosZenithAngle,
        (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM),
        rainStrength);
    
    return textureLod(tex, uv, 0).rgb;
}

#if !defined RENDER_PREPARE_SKY_LUT && ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
    vec3 getValFromSkyLUT(const in float worldY, const in vec3 localViewDir, const in float lod) {
        float height = GetScaledSkyHeight(worldY);

        //vec3 sunDir = GetSunDir();

        // #if SHADER_PLATFORM == PLATFORM_OPTIFINE
        //     vec3 up = vec3(0.0, 1.0, 0.0);//gbufferModelView[1].xyz;
        // #else
        //     vec3 up = normalize(upPosition);
        // #endif
        const vec3 up = vec3(0.0, 1.0, 0.0);

        float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height);
        float altitudeAngle = horizonAngle - acos(dot(localViewDir, up)); // Between -PI/2 and PI/2
        float azimuthAngle; // Between 0 and 2*PI

        if (abs(altitudeAngle) > (0.5*PI - 0.0001)) {
            // Looking nearly straight up or down.
            azimuthAngle = 0.0;
        } else {
            vec3 right = vec3(1.0, 0.0, 0.0);
            vec3 forward = vec3(0.0, 0.0, -1.0);

            vec3 projectedDir = normalize(localViewDir - up*(dot(localViewDir, up)));
            float sinTheta = dot(projectedDir, right);
            float cosTheta = dot(projectedDir, forward);
            azimuthAngle = atan(sinTheta, cosTheta) + PI;
        }
        
        // Non-linear mapping of altitude angle. See Section 5.3 of the paper.
        float v = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0 / PI);
        vec2 uv = vec2(azimuthAngle / (2.0*PI), v);
        
        return textureLod(BUFFER_SKY_LUT, uv, lod).rgb;
    }

    vec3 GetFancySkyLuminance(const in float worldY, const in vec3 localViewDir, const in float lod) {
        return NightSkyLumen + getValFromSkyLUT(worldY, localViewDir, lod) * SKY_FANCY_LUM;
    }
#endif
