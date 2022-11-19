vec3 GetLabPbr_Normal(const in vec2 normalXY) {
    return RestoreNormalZ(normalXY);
}

vec3 GetOldPbr_Normal(in vec3 normal) {
    normal = normal * 2.0 - 1.0;
    return normalize(normal);
}

float GetLabPbr_F0(const in float specularG) {
    return specularG * step(specularG, 0.9);
}

int GetLabPbr_HCM(const in float specularG) {
    return int(floor(specularG * 255.0 - 229.5));
}

float GetLabPbr_SSS(const in float specularB) {
    return max(specularB - 0.25, 0.0) * (1.0 / 0.75);
}

float GetLabPbr_Porosity(const in float specularB) {
    return specularB * 4.0 * step(specularB, 0.25);
}

float GetOldPbr_Porosity(const in float smoothness, const in float metalness) {
    return (1.0 - smoothness) * (1.0 - metalness);
}

float GetLabPbr_Emission(const in float specularA) {
    return specularA * step(specularA, 1.0 - EPSILON);
}

#ifdef RENDER_DEFERRED
    // Read from gbuffers
    void PopulateMaterial(out PbrMaterial material, const in vec3 colorMap, const in vec4 normalMap, const in vec4 specularMap) {
        material.albedo.rgb = RGBToLinear(colorMap);
        material.albedo.a = 1.0;

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            material.f0 = GetLabPbr_F0(specularMap.g);
            material.hcm = GetLabPbr_HCM(specularMap.g);
            material.occlusion = normalMap.a;
            //material.porosity = GetLabPbr_Porosity(specularMap.b);

            if (material.f0 < EPSILON) material.f0 = 0.04;
        #else
            material.f0 = saturate(specularMap.g);
            material.hcm = -1;
            material.occlusion = 1.0;
            //material.porosity = GetOldPbr_Porosity(specularMap.r, specularMap.g);
        #endif

        material.smoothness = specularMap.r;
        material.normal = normalize(normalMap.xyz * 2.0 - 1.0);
        material.porosity = GetLabPbr_Porosity(specularMap.b);
        material.scattering = GetLabPbr_SSS(specularMap.b);
        material.emission = specularMap.a;
    }
#else
    // Read from atlas
    void PopulateMaterial(out PbrMaterial material, const in vec4 colorMap, const in vec3 normalMap, const in vec4 specularMap) {
        material.albedo.rgb = RGBToLinear(colorMap.rgb);
        material.albedo.a = colorMap.a;

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
            if (all(lessThan(normalMap.xy, vec2(EPSILON))))
                material.normal = vec3(0.0, 0.0, 1.0);
            else {
                material.normal = GetLabPbr_Normal(normalMap.xy);
            }

            material.occlusion = normalMap.b;
            material.smoothness = specularMap.r;
            material.f0 = GetLabPbr_F0(specularMap.g);
            material.hcm = GetLabPbr_HCM(specularMap.g);
            material.porosity = GetLabPbr_Porosity(specularMap.b);
            material.scattering = GetLabPbr_SSS(specularMap.b);
            material.emission = GetLabPbr_Emission(specularMap.a);

            if (material.f0 < EPSILON) material.f0 = 0.04;
        #elif MATERIAL_FORMAT == MATERIAL_FORMAT_OLDPBR
            if (all(lessThan(normalMap.xyz, vec3(EPSILON))))
                material.normal = vec3(0.0, 0.0, 1.0);
            else {
                material.normal = GetOldPbr_Normal(normalMap);
            }

            material.f0 = specularMap.g;
            //material.hcm = specularMap.g >= 0.5 ? 15 : -1;
            material.smoothness = specularMap.r;
            material.porosity = GetOldPbr_Porosity(specularMap.r, specularMap.g);
            material.occlusion = 1.0;
            material.hcm = -1;
        #elif MATERIAL_FORMAT == MATERIAL_FORMAT_PATRIX
            if (normalMap.x < EPSILON && normalMap.y < EPSILON)
                material.normal = vec3(0.0, 0.0, 1.0);
            else {
                material.normal = GetOldPbr_Normal(normalMap);
            }

            material.smoothness = specularMap.r;
            material.scattering = GetLabPbr_SSS(specularMap.b);
            material.emission = GetLabPbr_Emission(specularMap.a);
            material.f0 = specularMap.g;
            //material.hcm = specularMap.g >= 0.5 ? 15 : -1;
            material.porosity = GetOldPbr_Porosity(specularMap.r, specularMap.g);
            material.occlusion = 1.0;
            //material.f0 = 0.04;
            material.hcm = -1;
        #elif MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            material.normal = vec3(0.0, 0.0, 1.0);
            material.smoothness = 0.08;
            material.occlusion = 1.0;
            material.f0 = 0.04;
            material.hcm = -1;
        #endif
    }

    float WriteLabPbr_Porosity(const in float porosity) {
        return 0.25 * saturate(porosity);
    }

    float WriteLabPbr_SSS(const in float scattering) {
        return 0.255 + 0.745 * scattering;
    }

    float WriteLabPbr_F0(const in float f0) {
        return clamp(f0, 0.0, 0.898);
    }

    float WriteLabPbr_HCM(const in float hcm) {
        return 0.902 + 0.98 * hcm;
    }

    void WriteMaterial(const in PbrMaterial material, out vec4 colorMap, out vec4 normalMap, out vec4 specularMap) {
        colorMap.rgb = LinearToRGB(material.albedo.rgb);
        colorMap.a = material.albedo.a;

        normalMap.xyz = material.normal * 0.5 + 0.5;
        normalMap.a = material.occlusion;

        specularMap.r = material.smoothness;

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            specularMap.g = material.hcm >= 0
                ? WriteLabPbr_HCM(material.hcm)
                : WriteLabPbr_F0(material.f0);
        #else
            specularMap.g = material.f0;
        #endif

        specularMap.b = material.scattering > EPSILON
            ? WriteLabPbr_SSS(material.scattering)
            : WriteLabPbr_Porosity(material.porosity);

        specularMap.a = material.emission;
    }
#endif
