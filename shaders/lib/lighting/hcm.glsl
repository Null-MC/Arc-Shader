// R=670 nm
// G=550 nm
// B=430 nm

// const vec3 ior_n_iron = vec3(2.4680, 2.1890, 1.6310);
// const vec3 ior_k_iron = vec3(3.4040, 3.1710, 2.8060);

// const vec3 ior_n_gold = vec3(0.17410, 0.42108, 1.4762);
// const vec3 ior_k_gold = vec3(3.6123, 2.3459, 1.8135);

// const vec3 ior_n_aluminum = vec3(1.5196, 0.96565, 0.53124);
// const vec3 ior_k_aluminum = vec3(7.6635, 6.4581, 5.0699);

// const vec3 ior_n_chrome = vec3(3.6400, 2.9008, 1.9906);
// const vec3 ior_k_chrome = vec3(4.3511, 4.2311, 3.7505);

// const vec3 ior_n_copper = vec3(0.24052, 0.67693, 1.3379);
// const vec3 ior_k_copper = vec3(3.8090, 2.6248, 2.2981);

// const vec3 ior_n_lead = vec3(2.5298, 2.5444, 1.8967);
// const vec3 ior_k_lead = vec3(4.1709, 4.1823, 4.1552);

// const vec3 ior_n_platinum = vec3(2.4390, 2.0847, 1.7998);
// const vec3 ior_k_platinum = vec3(4.3677, 3.7153, 3.0211);

// const vec3 ior_n_silver = vec3(0.16262, 0.14512, 0.13550);
// const vec3 ior_k_silver = vec3(4.0728, 3.1900, 2.1997);


//=======================
// R=650 nm
// G=550 nm
// B=450 nm

const vec3 ior_n_iron = vec3(2.9114, 2.9497, 2.5845);
const vec3 ior_k_iron = vec3(3.0893, 2.9318, 2.7670);

const vec3 ior_n_gold = vec3(0.18299, 0.42108, 1.3734);
const vec3 ior_k_gold = vec3(3.4242, 2.3459, 1.7704);

const vec3 ior_n_aluminum = vec3(1.5196, 0.96565, 0.53124);
const vec3 ior_k_aluminum = vec3(7.6635, 6.4581, 5.0699);

const vec3 ior_n_chrome = vec3(3.6400, 2.9008, 1.9906);
const vec3 ior_k_chrome = vec3(4.3511, 4.2311, 3.7505);

const vec3 ior_n_copper = vec3(0.27105, 0.67693, 1.3164);
const vec3 ior_k_copper = vec3(3.6092, 2.6248, 2.2921);

const vec3 ior_n_lead = vec3(2.5298, 2.5444, 1.8967);
const vec3 ior_k_lead = vec3(4.1709, 4.1823, 4.1552);

const vec3 ior_n_platinum = vec3(2.4390, 2.0847, 1.7998);
const vec3 ior_k_platinum = vec3(4.3677, 3.7153, 3.0211);

const vec3 ior_n_silver = vec3(0.16262, 0.14512, 0.13550);
const vec3 ior_k_silver = vec3(4.0728, 3.1900, 2.1997);


const vec3 ior_n[8] = vec3[](
    ior_n_iron,
    ior_n_gold,
    ior_n_aluminum,
    ior_n_chrome,
    ior_n_copper,
    ior_n_lead,
    ior_n_platinum,
    ior_n_silver);

const vec3 ior_k[8] = vec3[](
    ior_k_iron,
    ior_k_gold,
    ior_k_aluminum,
    ior_k_chrome,
    ior_k_copper,
    ior_k_lead,
    ior_k_platinum,
    ior_k_silver);


void GetHCM_IOR(const in vec3 albedo, const in int hcm, out vec3 n, out vec3 k) {
    if (hcm < 8) {
        // HCM conductor
        n = ior_n[hcm];
        k = ior_k[hcm];
    }
    else {
        // albedo-only conductor
        n = vec3(f0ToIOR(albedo));
        k = albedo;
    }
}

vec3 GetHCM_Tint(const in vec3 albedo, const in int hcm) {
    if (hcm < 0) return vec3(1.0);
    //else if (hcm < 8) return IORToF0(ior_n[hcm]);
    else return vec3(albedo);
}
