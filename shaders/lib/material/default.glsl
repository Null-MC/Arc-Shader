void ApplyHardCodedMaterials(out float f0, out float sss, out float smoothness, out float emissive) {
    f0 = 0.04;
    sss = 0.0;
    smoothness = 0.0;
    emissive = 0.0;

    if (mc_Entity.x == 100.0 || mc_Entity.x == 101.0) {
        // Water
        smoothness = 0.98;
        f0 = 0.02;
    }
    else if (mc_Entity.x == 102.0) {
        // Nether Portal
        emissive = 0.8;
    }
    else if (mc_Entity.x >= 10000.5 && mc_Entity.x <= 10004.5) {
        // Foliage
        smoothness = 0.08;
        sss = 0.7;
        f0 = 0.03;
    }
    else if (mc_Entity.x >= 11000.0 && mc_Entity.x < 11010) {
        // Metals
        if (mc_Entity.x == 11000) {
            // Iron
            smoothness = 0.8;
            f0 = 230.5/255.0;
        }
        else if (mc_Entity.x == 11001) {
            // Gold
            smoothness = 0.9;
            f0 = 231.5/255.0;
        }
        else if (mc_Entity.x == 11004) {
            // Copper
            smoothness = 0.75;
            f0 = 234.5/255.0;
        }
    }
    else if (mc_Entity.x >= 11010.0 && mc_Entity.x < 11100) {
        // SSS
        if (mc_Entity.x == 11010) {
            // Snow
            smoothness = 0.4;
            f0 = 0.02;
            sss = 0.6;
        }
        else if (mc_Entity.x == 11011) {
            // Slime
            smoothness = 0.55;
            f0 = 0.04;
            sss = 0.6;
        }
    }
    else if (mc_Entity.x >= 11100.0 && mc_Entity.x < 11200) {
        // Smooth
        if (mc_Entity.x == 11100) {
            // Ice
            smoothness = 0.94;
            f0 = 0.02;
            sss = 0.9;
        }
        else if (mc_Entity.x == 11101) {
            // Polished blocks
            smoothness = 0.65;
            f0 = 0.04;
        }
    }
    else if (mc_Entity.x >= 11200.0) {
        // Special
        if (mc_Entity.x == 11200) {
            // Diamond
            smoothness = 0.98;
            f0 = 0.172;
            sss = 0.9;
        }
        else if (mc_Entity.x == 11201) {
            // Emerald
            smoothness = 0.8;
            f0 = 0.053;
            sss = 0.6;
        }
        else if (mc_Entity.x == 11202) {
            // Obsidian
            smoothness = 0.94;
            f0 = 0.047;
            sss = 0.2;
        }
    }
}
