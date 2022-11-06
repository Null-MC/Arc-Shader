float F_schlick(const in float cos_theta, const in float f0, const in float f90) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (f90 - f0) * pow5(invCosTheta);
}

float F_SchlickRoughness(const in float f0, const in float cos_theta, const in float rough) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (max(1.0 - rough, f0) - f0) * pow5(invCosTheta);
}

vec3 F_conductor(const in float VoH, const in float n1, const in vec3 n2, const in vec3 k) {
    vec3 eta = n2 / n1;
    vec3 eta_k = k / n1;

    float cos_theta2 = pow2(VoH);
    float sin_theta2 = 1.0f - cos_theta2;
    vec3 eta2 = pow2(eta);
    vec3 eta_k2 = pow2(eta_k);

    vec3 t0 = eta2 - eta_k2 - sin_theta2;
    vec3 a2_plus_b2 = sqrt(t0 * t0 + 4.0f * eta2 * eta_k2);
    vec3 t1 = a2_plus_b2 + cos_theta2;
    vec3 a = sqrt(0.5f * (a2_plus_b2 + t0));
    vec3 t2 = 2.0f * a * VoH;
    vec3 rs = (t1 - t2) / (t1 + t2);

    vec3 t3 = cos_theta2 * a2_plus_b2 + sin_theta2 * sin_theta2;
    vec3 t4 = t2 * sin_theta2;
    vec3 rp = rs * (t3 - t4) / (t3 + t4);

    return 0.5f * (rp + rs);
}

vec3 F_Lazanyi2019(const in float cosTheta, const in vec3 f0, const in vec3 f82) {
    vec3 a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
    return saturate(f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0) - a * cosTheta * pow(1.0 - cosTheta, 6.0));
}
