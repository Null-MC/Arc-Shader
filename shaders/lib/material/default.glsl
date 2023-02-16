vec3 GetRandomNormal(const in vec3 texPos, const in float maxTheta) {
    vec3 randomNormal = hash33(texPos) * 2.0 - 1.0;
    randomNormal.z *= sign(randomNormal.z);
    randomNormal = mix(vec3(0.0, 0.0, 1.0), randomNormal, maxTheta);
    return normalize(randomNormal);
}

void ApplyHardCodedMaterials(inout PbrMaterial material, const in int materialId, const in vec3 worldPos) {
    material.occlusion = 1.0;
    material.normal = vec3(0.0, 0.0, 1.0);
    material.scattering = 0.0;
    material.smoothness = 0.0;
    material.emission = 0.0;
    material.porosity = 0.7;
    material.hcm = -1;
    material.f0 = 0.04;

    float noiseTheta = 0.0;

    if (materialId == MATERIAL_WATER) {
        material.smoothness = WATER_SMOOTH;
        material.f0 = 0.02;
        material.porosity = 0.0;
    }
    else if (materialId == ENTITY_PHYSICSMOD_SNOW) {
        material.scattering = 0.4;
        //...
    }
    else if (materialId == 100 || materialId == 101) {
        // Water
        material.smoothness = 0.98;
        material.f0 = 0.02;
        material.porosity = 0.0;
    }
    else if (materialId == 102) {
        // Nether Portal
        material.emission = 0.8;
        material.porosity = 0.0;
    }
    else if (materialId >= 10000 && materialId <= 10004) {
        // Foliage
        noiseTheta = 0.02;
        material.smoothness = 0.08;
        material.scattering = 0.7;
        material.f0 = 0.03;
        material.porosity = 0.3;
    }
    else if (materialId >= 10900 && materialId <= 10999) {
        // General
        if (materialId == 10900) {
            // Dirt
            noiseTheta = 0.2;
        }
        else if (materialId == 10901) {
            // Grass
            noiseTheta = 0.2;
        }
        else if (materialId == 10910) {
            // Torch
            material.emission = 0.8 * step(250.0/255.0, material.albedo.r);
        }
    }
    else if (materialId >= 11000 && materialId < 11060) {
        // Metals
        if (materialId == 11000) {
            // Iron
            noiseTheta = 0.04;
            material.hcm = 230;
            material.smoothness = 0.7;
            material.porosity = 0.0;
        }
        else if (materialId == 11001) {
            // Gold
            noiseTheta = 0.02;
            material.hcm = 231;
            material.smoothness = 0.8;
            material.porosity = 0.0;
        }
        else if (materialId == 11004) {
            // Copper
            noiseTheta = 0.06;
            material.hcm = 234;
            material.smoothness = 0.5;
            material.porosity = 0.0;
        }
        else if (materialId == 11020) {
            // Copper
            noiseTheta = 0.12;
            material.hcm = 255;
            material.smoothness = 0.3;
            material.porosity = 0.1;
        }
    }
    else if (materialId >= 11060 && materialId < 11100) {
        // SSS
        if (materialId == 11060) {
            // Snow
            noiseTheta = 0.1;
            material.f0 = 0.02;
            material.smoothness = 0.4;
            material.scattering = 0.6;
            material.porosity = 0.6;
            //material.height = 1.0 - min(luminance(material.albedo.rgb) + 0.1, 1.0);
        }
        else if (materialId == 11061) {
            // Slime & Honey
            material.f0 = 0.04;
            material.smoothness = 0.55;
            material.scattering = 0.6;
            material.porosity = 0.0;
        }
    }
    else if (materialId >= 11100 && materialId < 11200) {
        // Smooth
        if (materialId == 11100) {
            // Ice
            noiseTheta = 0.06;
            material.f0 = 0.02;
            material.smoothness = 0.94;
            material.scattering = 0.9;
            material.porosity = 0.3;
        }
        else if (materialId == 11101) {
            // Polished blocks
            material.smoothness = 0.65;
            material.f0 = 0.04;
            material.porosity = 0.15;
        }
    }
    else if (materialId >= 11200) {
        // Special
        if (materialId == 11200) {
            // Diamond
            material.smoothness = 0.98;
            material.f0 = 0.172;
            material.scattering = 0.9;
            material.porosity = 0.05;
        }
        else if (materialId == 11201) {
            // Emerald
            noiseTheta = 0.02;
            material.f0 = 0.053;
            material.smoothness = 0.8;
            material.scattering = 0.6;
            material.porosity = 0.05;
        }
        else if (materialId == 11202) {
            // Obsidian
            noiseTheta = 0.14;
            material.f0 = 0.047;
            material.smoothness = 0.94;
            material.scattering = 0.2;
            material.porosity = 0.05;
        }
    }
    else if (materialId >= 11300) {
        // Logs
        if (materialId == 11300) {
            // Vertical
            material.f0 = 0.03;
            material.smoothness = 0.06;
            material.scattering = 0.0;
            material.porosity = 0.8;
        }
    }

    if (noiseTheta > 0.0) {
        vec3 texPos = floor(worldPos * 16.0 + 0.01) / 16.0 + floor(worldPos + 0.5)/32.0;
        material.normal = GetRandomNormal(texPos, noiseTheta);
    }
}
