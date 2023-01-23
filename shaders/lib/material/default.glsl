void ApplyHardCodedMaterials(inout PbrMaterial material, const in int materialId) {
    material.occlusion = 1.0;
    material.normal = vec3(0.0, 0.0, 1.0);
    material.scattering = 0.0;
    material.smoothness = 0.0;
    material.emission = 0.0;
    material.porosity = 0.7;
    material.hcm = -1;
    material.f0 = 0.04;

    if (materialId == MATERIAL_WATER) {
        material.smoothness = WATER_SMOOTH;
        material.f0 = 0.02;
        material.porosity = 0.0;
    }
    else if (materialId == MATERIAL_PHYSICS_SNOW) {
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
        material.smoothness = 0.08;
        material.scattering = 0.7;
        material.f0 = 0.03;
        material.porosity = 0.3;
    }
    else if (materialId >= 11000 && materialId < 11010) {
        // Metals
        if (materialId == 11000) {
            // Iron
            material.smoothness = 0.8;
            material.f0 = 230.5/255.0;
            material.porosity = 0.0;
        }
        else if (materialId == 11001) {
            // Gold
            material.smoothness = 0.9;
            material.f0 = 231.5/255.0;
            material.porosity = 0.0;
        }
        else if (materialId == 11004) {
            // Copper
            material.smoothness = 0.75;
            material.f0 = 234.5/255.0;
            material.porosity = 0.0;
        }
    }
    else if (materialId >= 11010 && materialId < 11100) {
        // SSS
        if (materialId == 11010) {
            // Snow
            material.smoothness = 0.4;
            material.f0 = 0.02;
            material.scattering = 0.6;
            material.porosity = 0.6;
        }
        else if (materialId == 11011) {
            // Slime
            material.smoothness = 0.55;
            material.f0 = 0.04;
            material.scattering = 0.6;
            material.porosity = 0.0;
        }
    }
    else if (materialId >= 11100 && materialId < 11200) {
        // Smooth
        if (materialId == 11100) {
            // Ice
            material.smoothness = 0.94;
            material.f0 = 0.02;
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
            material.smoothness = 0.8;
            material.f0 = 0.053;
            material.scattering = 0.6;
            material.porosity = 0.05;
        }
        else if (materialId == 11202) {
            // Obsidian
            material.smoothness = 0.94;
            material.f0 = 0.047;
            material.scattering = 0.2;
            material.porosity = 0.05;
        }
    }
}
