void ApplyHardCodedMaterials(inout PbrMaterial material, const in int entityId) {
    material.occlusion = 1.0;
    material.normal = vec3(0.0, 0.0, 1.0);
    material.scattering = 0.0;
    material.smoothness = 0.08;
    material.emission = 0.0;
    material.porosity = 0.0;
    material.hcm = -1;
    material.f0 = 0.04;

    if (entityId == ENTITY_SLIME) {
        //material.albedo = vec4(1.0, 0.0, 0.0, 1.0);
        material.f0 = 0.03;
        material.smoothness = 0.68;
        material.scattering = 0.8;
    }
    else if (entityId == ENTITY_PHYSICSMOD_SNOW) {
        material.f0 = 0.02;
        material.scattering = 0.6;
    }
}
