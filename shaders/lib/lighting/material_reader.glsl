vec3 GetLabPbr_Normal(const in vec2 normalXY) {
    return RestoreNormalZ(normalXY);
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

float GetLabPbr_Emission(const in float specularA) {
    return specularA * step(specularA, 1.0 - EPSILON);
}

#ifdef RENDER_DEFERRED
    void PopulateMaterial(out PbrMaterial material, const in vec3 colorMap, const in vec4 normalMap, const in vec4 specularMap) {
        material.albedo.rgb = RGBToLinear(colorMap);
        material.albedo.a = 1.0;

        material.f0 = GetLabPbr_F0(specularMap.g);
        material.hcm = GetLabPbr_HCM(specularMap.g);
        material.normal = RestoreNormalZ(normalMap.xy);
        material.occlusion = normalMap.z;
        material.smoothness = specularMap.r;
        material.porosity = GetLabPbr_Porosity(specularMap.b);
        material.scattering = GetLabPbr_SSS(specularMap.b);
        material.emission = GetLabPbr_Emission(specularMap.a);
    }
#elif defined RENDER_WATER
    void PopulateMaterial(out PbrMaterial material, const in vec2 atlasCoord, const in mat2 dFdXY) {
    	vec4 colorMap = textureGrad(gtexture, atlasCoord, dFdXY[0], dFdXY[1]) * glcolor;
    	vec4 normalMap = textureGrad(normals, atlasCoord, dFdXY[0], dFdXY[1]);
    	vec4 specularMap = textureGrad(specular, atlasCoord, dFdXY[0], dFdXY[1]);

        material.albedo.rgb = RGBToLinear(colorMap.rgb);
        material.albedo.a = colorMap.a;

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR
            if (normalMap.x < EPSILON && normalMap.y < EPSILON)
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
            if (normalMap.x < EPSILON && normalMap.y < EPSILON)
                material.normal = vec3(0.0, 0.0, 1.0);
            else {
                material.normal = normalMap.xyz * 2.0 - 1.0;
            }

            material.f0 = specularMap.g < 0.5 ? 0.04 : 0.0;
            material.hcm = specularMap.g >= 0.5 ? 15 : -1;
            material.smoothness = specularMap.r;
            material.occlusion = 1.0;
        #else
            material.normal = vec3(0.0, 0.0, 1.0);
            material.smoothness = 0.08;
            material.occlusion = 1.0;
            material.f0 = 0.04;
        #endif
    }
#endif
