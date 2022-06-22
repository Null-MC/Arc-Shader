#ifdef RENDER_VERTEX
    void PbrVertex(const in mat3 matViewTBN) {
        #ifdef PARALLAX_ENABLED
            tanViewPos = matViewTBN * viewPos;

            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            localCoord = sign(coordNMid) * 0.5 + 0.5;
        #endif
    }
#endif

#ifdef RENDER_FRAG
    #define IOR_AIR 1.0

    float F_schlick(const in float f0, const in float fd90, const in float cos_theta)
    {
        return f0 + (fd90 - f0) * pow(1.0 - cos_theta, 5.0);
    }

    float SchlickRoughness(const in float f0, const in float cos_theta, const in float rough) {
        return f0 + (max(1.0 - rough, f0) - f0) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0);
    }

    vec3 F_conductor(const in float VoH, const in float n1, const in vec3 n2, const in vec3 k)
    {
        vec3 eta = n2 / n1;
        vec3 eta_k = k / n1;

        float cos_theta2 = VoH * VoH;
        float sin_theta2 = 1.0f - cos_theta2;
        vec3 eta2 = eta * eta;
        vec3 eta_k2 = eta_k * eta_k;

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

    // vec3 SchlickRoughness(const in vec3 f0, const in float cos_theta, const in float rough) {
    //     return f0 + (max(1.0 - rough, f0) - f0) * pow(saturate(1.0 - cos_theta), 5.0);
    // }

    float GGX(const in float NoH, const in float roughL)
    {
        const float a = NoH * roughL;
        const float k = roughL / (1.0 - NoH * NoH + a * a);
        return k * k * (1.0 / PI);
    }

    float SmithHable(const in float LdotH, const in float alpha)
    {
        return 1.0 / mix(LdotH * LdotH, 1.0, alpha * alpha * 0.25);
    }

    float Specular_BRDF(const in float f0, const in float LoH, const in float NoH, const in float VoH, const in float roughL)
    {
        // Fresnel
        float F = SchlickRoughness(f0, VoH, roughL);

        // Distribution
        float D = GGX(NoH, roughL);

        // Geometric Visibility
        float G = SmithHable(LoH, roughL);

        return D * F * G;
    }

    vec3 SpecularConductor_BRDF(const in vec3 iorN, const in vec3 iorK, const in float LoH, const in float NoH, const in float VoH, const in float roughL)
    {
        // Fresnel
        //float F = SchlickRoughness(f0, VoH, roughL);
        //vec3 F = F_conductor(LoH, ior_n1, ior_n2, ior_k);
        vec3 F = F_conductor(VoH, IOR_AIR, iorN, iorK);

        // Distribution
        float D = GGX(NoH, roughL);

        // Geometric Visibility
        float G = SmithHable(LoH, roughL);

        return D * F * G;
    }

    float Diffuse_Burley(const in float NoL, const in float NoV, const in float LoH, const in float rough)
    {
        float f90 = 0.5 + 2.0 * LoH * LoH * rough;
        float light_scatter = F_schlick(1.0, f90, NoL);
        float view_scatter = F_schlick(1.0, f90, NoV);
        return light_scatter * view_scatter * InvPI;
    }

#endif
