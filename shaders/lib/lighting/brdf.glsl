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

float GGX(const in float NoH, const in float roughL) {
    float a = NoH * roughL;
    float k = roughL / (1.0 - pow2(NoH) + pow2(a));
    //return pow2(k) * invPI;
    return min(pow2(k) * invPI, 65504.0);
}

float GGX_Fast(const in float NoH, const in vec3 NxH, const in float roughL) {
    float a = NoH * roughL;
    float k = roughL / (dot(NxH, NxH) + pow2(a));
    return min(pow2(k) * invPI, 65504.0);
}

float SmithGGXCorrelated(const in float NoV, const in float NoL, const in float roughL) {
    float a2 = pow2(roughL);
    float GGXV = NoL * sqrt(max(NoV * NoV * (1.0 - a2) + a2, EPSILON));
    float GGXL = NoV * sqrt(max(NoL * NoL * (1.0 - a2) + a2, EPSILON));
    return saturate(0.5 / (GGXV + GGXL));
}

float SmithGGXCorrelated_Fast(const in float NoV, const in float NoL, const in float roughL) {
    float GGXV = NoL * (NoV * (1.0 - roughL) + roughL);
    float GGXL = NoV * (NoL * (1.0 - roughL) + roughL);
    return saturate(0.5 / (GGXV + GGXL));
}

float SmithHable(const in float LoH, const in float alpha) {
    return rcp(mix(pow2(LoH), 1.0, pow2(alpha) * 0.25));
}

vec3 GetFresnel(const in vec3 albedo, const in float f0, const in int hcm, const in float VoH, const in float roughL) {
    #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
        if (hcm >= 0) {
            #ifdef HCM_LAZANYI
                vec3 hcm_f0, hcm_f82;
                GetHCM_IOR(albedo, hcm, hcm_f0, hcm_f82);
                return F_Lazanyi2019(VoH, hcm_f0, hcm_f82);
            #else
                vec3 iorN, iorK;
                GetHCM_IOR(albedo, hcm, iorN, iorK);
                return F_conductor(VoH, IOR_AIR, iorN, iorK);
            #endif
        }
        else {
            return vec3(F_SchlickRoughness(f0, VoH, roughL));
        }
    #else
        float dielectric_F = 0.0;
        if (f0 + EPSILON < 1.0)
            dielectric_F = F_SchlickRoughness(0.04, VoH, roughL);

        vec3 conductor_F = vec3(0.0);
        if (f0 - EPSILON > 0.04) {
            vec3 iorN = vec3(f0ToIOR(albedo));
            conductor_F = F_conductor(VoH, IOR_AIR, iorN, albedo);
        }

        float metalF = saturate((f0 - 0.04) * (1.0/0.96));
        return mix(vec3(dielectric_F), conductor_F, metalF);
    #endif
}

vec3 GetSpecularBRDF(const in vec3 F, const in float NoV, const in float NoL, const in float NoH, const in float roughL) {
    // Fresnel
    //vec3 F = GetFresnel(material, VoH, roughL);

    // Distribution
    float D = GGX(NoH, roughL);

    // Geometric Visibility
    float G = SmithGGXCorrelated_Fast(NoV, NoL, roughL);

    return D * F * G;
}

vec3 GetDiffuse_Burley(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + 2.0 * roughL * pow2(LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    return (albedo * invPI) * light_scatter * view_scatter * NoL;
}

vec3 GetSubsurface(const in vec3 albedo, const in float NoVm, const in float NoL, const in float LoHm, const in float roughL) {
    float NoLm = max(NoL, 0.0);

    float sssF90 = roughL * pow2(LoHm);
    float sssF_In = F_schlick(NoVm, 1.0, sssF90);
    float sssF_Out = F_schlick(NoLm, 1.0, sssF90);

    // TODO: modified this to prevent NaN's!
    //return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (1.0 / (NoVm + NoLm) - 0.5) + 0.5) * abs(NoL);
    vec3 result = (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (min(1.0 / max(NoVm + NoLm, 0.0001), 1.0) - 0.5) + 0.5) * max(NoL, 0.0);
    //return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (rcp(1.0 + (NoV + NoL)) - 0.5) + 0.5);

    #ifndef SHADOW_ENABLED
        result *= abs(NoL);
    #endif

    return result;
}

vec3 GetDiffuseBSDF(const in vec3 diffuse, const in vec3 albedo, const in float scattering, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    //vec3 diffuse = GetDiffuse_Burley(material.albedo.rgb, NoV, NoL, LoH, roughL);

    #ifdef SSS_ENABLED
        if (scattering < EPSILON) return diffuse;

        vec3 subsurface = GetSubsurface(albedo, NoV, NoL, LoH, roughL);
        return mix(diffuse, subsurface, scattering);
    #else
        return diffuse;
    #endif
}

float BiLambertianPlatePhaseFunction(in float kd, in float cosTheta) {
    float phase = 2.0 * (-PI * kd * cosTheta + sqrt(1.0 - pow2(cosTheta)) + cosTheta * acos(-cosTheta));
    return phase / (3.0 * pow2(PI));
}
