//euclidian distance is defined as sqrt(a^2 + b^2 + ...)
//this length function instead does cbrt(a^3 + b^3 + ...)
//this results in smaller distances along the diagonal axes.
float cubeLength(const in vec2 v) {
    vec2 t = abs(pow3(v));
    return pow(t.x + t.y, 1.0/3.0);
}

float getDistortFactor(const in vec2 v) {
    return cubeLength(v) + SHADOW_DISTORT_FACTOR;
}



float getUndistortFactor(const in vec2 v) {
    // TODO: This is wrong!
    return 1.0 - getDistortFactor(v);
    //return v / (SHADOW_DISTORT_FACTOR + cubeLength(v));
}

vec2 distort(const in vec2 v, const in float factor) {
    return v / factor;
}

vec3 distort(const in vec3 v, const in float factor) {
    return vec3(v.xy / factor, v.z);
}

vec2 undistort(const in vec2 v, const in float factor) {
    return v * factor;
}

vec3 undistort(const in vec3 v, const in float factor) {
    return vec3(v.xy * factor, v.z);
}

vec2 distort(const in vec2 v) {
    return distort(v, getDistortFactor(v));
}

vec3 distort(const in vec3 v) {
    return distort(v, getDistortFactor(v.xy));
}

vec2 undistort(const in vec2 v) {
    return undistort(v, getUndistortFactor(v));
}

vec3 undistort(const in vec3 v) {
    return undistort(v, getUndistortFactor(v.xy));
}


float GetShadowBias(const in float geoNoL, const in float distortFactor) {
    //shadowPos.z -= SHADOW_DISTORTED_BIAS * SHADOW_BIAS_SCALE * (distortFactor * distortFactor) / abs(geoNoL);
    //float df2 = distortFactor;//*distortFactor;

    const float minBias = 0.0001;
    const float biasZ = 0.0001;
    float biasXY = 0.5 * shadowPixelSize;
    return 0.15 * (minBias + mix(biasXY, biasZ, saturate(geoNoL))) * (SHADOW_BIAS_SCALE * 0.01);
}

// Zombye
// vec2 distort(vec2 p) {
//   vec2 tmp = abs(p * p * p);
//   return p / (c + pow(tmp.x + tmp.y, 1.0 / 3.0));
// }

// vec2 undistort(vec2 p) {
//   vec2 tmp = abs(p * p * p);
//   return c * p / (1.0 - pow(tmp.x + tmp.y, 1.0 / 3.0));
// }

#ifdef RENDER_VERTEX
    void ApplyShadows(const in vec3 shadowViewPos, const in vec3 viewDir) {}
#endif
