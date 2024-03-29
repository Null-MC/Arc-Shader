vec3 getValFromTLUT(const in vec3 pos, const in vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;

    float sunCosZenithAngle = dot(sunDir, up);
    vec3 uv = getAtmosLUT_UV(sunCosZenithAngle, height);
    
    return textureLod(TEX_SUN_TRANSMIT, uv, 0).rgb;
}

vec3 getValFromMultiScattLUT(const in vec3 pos, const in vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;

    float sunCosZenithAngle = dot(sunDir, up);
    vec3 uv = getAtmosLUT_UV(sunCosZenithAngle, height);
    
    return textureLod(TEX_MULTI_SCATTER, uv, 0).rgb;
}

#ifndef RENDER_PREPARE_SKY_LUT
    vec3 getValFromSkyLUT(const in float worldY, const in vec3 localViewDir, const in float lod) {
        float height = GetScaledSkyHeight(worldY);

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
        vec2 uv = vec2(azimuthAngle / TAU, v);
        
        return textureLod(BUFFER_SKY_LUT, uv, lod).rgb;
    }

    vec3 GetFancySkyLuminance(const in float worldY, const in vec3 localViewDir, const in float lod) {
        vec3 lum = getValFromSkyLUT(worldY, localViewDir, lod) * SKY_FANCY_LUM;
        
        #ifdef WORLD_OVERWORLD
            lum += NightSkyLumen;
        #endif

        return lum;
    }

    vec3 GetSunWithBloom(vec3 rayDir, vec3 sunDir) {
        const float sunSolidAngle = 1.0*(PI/180.0);
        const float minSunCosTheta = cos(sunSolidAngle);

        float cosTheta = dot(rayDir, sunDir);
        if (cosTheta >= minSunCosTheta) return vec3(1.0);
        
        float offset = minSunCosTheta - cosTheta;
        float gaussianBloom = exp(-offset*50000.0)*0.5;
        float invBloom = 1.0/(0.02 + offset*300.0)*0.01;
        return vec3(gaussianBloom+invBloom);
    }
#endif
