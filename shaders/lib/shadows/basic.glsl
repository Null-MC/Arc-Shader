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
