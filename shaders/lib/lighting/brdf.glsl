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

// modified by Jessie-LC
// vec3 GetDiffuse_HammonDiffuse(const in vec3 albedo, const in float n, const in float nDotV, const in float nDotL, in float nDotH, const in float lDotV, const in float roughness) {
//     //My modified Hammon diffuse model.
//     nDotH = abs(nDotH) + 1e-5;
//     float facing = 0.5 + 0.5 * lDotV;
//     float rough = nDotH <= 0.0 ? 0.0 : facing * (0.9 - 0.4 * facing) * ((1.0 + nDotH) * rcp(max(nDotH, 0.15)));
//     float fresnel_v = 1.0 - FresnelNonPolarized_R(nDotV, 1.00028, n);
//     float fresnel_l = 1.0 - FresnelNonPolarized_R(nDotL, 1.00028, n);
//     float energyConservationFactor = 1.0 - HemisphericalAlbedo(n / 1.00028);
//     float smooth_v = (fresnel_l * fresnel_v) * rcp(energyConservationFactor);
//     float single = mix(smooth_v, rough * 0.6, roughness) * rcp(pi);
//     float multi = 0.1159 * roughness;

//     return max(albedo * (single + albedo * multi) * nDotL, 0.0);
// }

// float HemisphericalAlbedo(const in float n) {
//     float n2 = square(n);
//     float T_1 = (4.0 * (2.0 * n + 1.0)) / (3.0 * square(n + 1.0));
//     float T_2 = ((4.0 * cube(n) * (n2 + 2.0 * n - 1.0)) / (square(n2 + 1.0) * (n2 - 1.0))) - 
//             ((2.0 * n2 * (n2 + 1.0) * log(n)) / square(n2 - 1.0)) +
//             ((2.0 * n2 * square(n2 - 1.0) * log((n * (n+1.0)) / (n-1.0))) / cube(n2 + 1.0));
//     return saturate(1.0 - 0.5 * (T_1 + T_2));
// }

vec3 GetDiffuse_Burley(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + roughL * pow2(LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    return (albedo * invPI) * light_scatter * view_scatter * NoL;
}

vec3 GetSubsurface(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float sssF90 = roughL * pow2(LoH);
    float sssF_In = F_schlick(NoV, 1.0, sssF90);
    float sssF_Out = F_schlick(NoL, 1.0, sssF90);

    // TODO: modified this to prevent NaN's!
    //return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (1.0 / (NoV + NoL) - 0.5) + 0.5) * abs(NoL);
    vec3 result = (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (min(1.0 / max(NoV + NoL, 0.0001), 1.0) - 0.5) + 0.5) * NoL;
    //return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (rcp(1.0 + (NoV + NoL)) - 0.5) + 0.5);

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

// https://www.desmos.com/calculator/c4xl06b2ww
float BiLambertianPlatePhaseFunction(in float kd, in float cosTheta) {
    float phase = 2.0 * (-PI * kd * cosTheta + sqrt(1.0 - pow2(cosTheta)) + cosTheta * acos(-cosTheta));
    return phase / (3.0 * pow2(PI));
}

vec3 CalculateExtinction(const in vec3 apparantColor, const in float scatterDistance) {
    vec3 apparantColor2 = pow2(apparantColor);
    vec3 apparantColor3 = apparantColor2 * apparantColor;

    vec3 alpha = vec3(1.0) - exp(-5.09406 * apparantColor + 2.61188 * apparantColor2 - 4.31805 * apparantColor3);
    vec3 a = apparantColor - vec3(0.8);
    vec3 s = vec3(1.9) - apparantColor + 3.5 * pow2(a);

    return min(rcp(max(s * scatterDistance, vec3(EPSILON))), 1.0);
}
