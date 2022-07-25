//euclidian distance is defined as sqrt(a^2 + b^2 + ...)
//this length function instead does cbrt(a^3 + b^3 + ...)
//this results in smaller distances along the diagonal axes.
float cubeLength(const in vec2 v) {
    return pow(abs(v.x * v.x * v.x) + abs(v.y * v.y * v.y), 1.0 / 3.0);
}

float getDistortFactor(const in vec2 v) {
    return cubeLength(v) + SHADOW_DISTORT_FACTOR;
}

vec2 getUndistortFactor(const in vec2 v) {
    return v.xy / (SHADOW_DISTORT_FACTOR + cubeLength(v));
}

vec3 distort(const in vec3 v, const in float factor) {
    return vec3(v.xy / factor, v.z * 0.5);
}

vec3 undistort(const in vec3 v, const in vec2 factor) {
    return vec3(v.xy * factor, v.z * 2.0);
}

vec3 distort(const in vec3 v) {
    return distort(v, getDistortFactor(v.xy));
}

vec3 undistort(const in vec3 v) {
    return undistort(v, getUndistortFactor(v.xy));
}


#if SHADOW_TYPE == SHADOW_TYPE_BASIC
    float GetShadowBias(const in float geoNoL) {
        float range = min(shadowDistance, far * SHADOW_CSM_FIT_FARSCALE);
        float shadowResScale = range / shadowMapSize;
        float bias = SHADOW_BASIC_BIAS * shadowResScale * SHADOW_BIAS_SCALE;
        //shadowPos.z -= min(bias / abs(geoNoL), 0.1);
        return min(bias / abs(geoNoL), 0.1);
    }
#elif SHADOW_TYPE == SHADOW_TYPE_DISTORTED
    float GetShadowBias(const in float geoNoL, const in float distortFactor) {
        //shadowPos.z -= SHADOW_DISTORTED_BIAS * SHADOW_BIAS_SCALE * (distortFactor * distortFactor) / abs(geoNoL);
        float df2 = distortFactor*distortFactor;
        float biasZ = 1e-8;//SHADOW_DISTORTED_BIAS * df2;
        float biasXY = shadowPixelSize * df2 * 32.0;
        return mix(biasXY, biasZ, geoNoL) * SHADOW_BIAS_SCALE;
    }
#endif

// Zombye
// vec2 distort(vec2 p) {
//   vec2 tmp = abs(p * p * p);
//   return p / (c + pow(tmp.x + tmp.y, 1.0 / 3.0));
// }

// vec2 undistort(vec2 p) {
//   vec2 tmp = abs(p * p * p);
//   return c * p / (1.0 - pow(tmp.x + tmp.y, 1.0 / 3.0));
// }
