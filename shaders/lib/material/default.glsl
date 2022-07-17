void ApplyHardCodedMaterials() {
    matSmooth = 0.08;
    matMetal = 0.04;
    matSSS = 0.0;

    if (mc_Entity.x == 100.0) {
        // Water
        matSmooth = 0.96;
        matMetal = 0.02;
    }

    if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0) {
        // Foliage
        matSmooth = 0.16;
        matMetal = 0.03;
        matSSS = 0.85;
    }
}
