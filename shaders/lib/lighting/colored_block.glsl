void AddSceneBlockLight(const in int blockId, const in vec3 blockLocalPos) {
    vec3 lightColor = vec3(0.0);
    vec3 lightOffset = vec3(0.0);
    float lightRange = 0.0;
    float flicker = 0.0;

    #ifdef LIGHT_FLICKER_ENABLED
        float time = frameTimeCounter / 3600.0;
        vec3 worldPos = cameraPosition + blockLocalPos;

        vec3 texPos = fract(worldPos.xzy * vec3(0.02, 0.02, 0.04));
        texPos.z += 900.0 * time;

        float flickerNoise = texture(TEX_CLOUD_NOISE, texPos).g;
    #endif

    switch (blockId) {
        case MATERIAL_SEA_LANTERN:
            lightColor = vec3(0.635, 0.909, 0.793);
            lightRange = 15.0;
            break;
        case MATERIAL_REDSTONE_LAMP:
            lightColor = vec3(0.953, 0.796, 0.496);
            lightRange = 15.0;
            break;
        case MATERIAL_TORCH:
            lightColor = vec3(0.934, 0.771, 0.395);
            lightRange = 12.0;
            flicker = 0.1;
            break;
        case MATERIAL_LANTERN:
            lightColor = vec3(0.906, 0.737, 0.451);
            lightRange = 12.0;
            flicker = 0.05;
            break;
        case MATERIAL_SOUL_TORCH:
            lightColor = vec3(0.510, 0.831, 0.851);
            lightRange = 12.0;
            flicker = 0.1;
            break;
        case MATERIAL_REDSTONE_TORCH:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightRange = 7.0;
            break;
        case MATERIAL_MAGMA:
            lightColor = 4.0 * vec3(0.804, 0.424, 0.149);
            lightRange = 3.0;
            break;
        case MATERIAL_GLOWSTONE:
            lightColor = vec3(0.742, 0.668, 0.468);
            lightRange = 15.0;
            break;
        case MATERIAL_GLOW_LICHEN:
            lightColor = vec3(0.232, 0.414, 0.214);
            lightRange = 7.0;
            break;
        case MATERIAL_END_ROD:
            lightColor = vec3(0.957, 0.929, 0.875);
            lightRange = 14.0;
            break;
        case MATERIAL_FIRE:
            lightColor = vec3(0.851, 0.616, 0.239);
            lightRange = 15.0;
            flicker = 0.3;
            break;
        case MATERIAL_NETHER_PORTAL:
            lightColor = vec3(0.502, 0.165, 0.831);
            lightRange = 11.0;
            break;
        case MATERIAL_CAVEVINE_BERRIES:
            lightColor = 0.4 * vec3(0.717, 0.541, 0.188);
            lightRange = 14.0;
            break;
        case MATERIAL_AMETHYST_CLUSTER:
            lightColor = vec3(0.537, 0.412, 0.765);
            lightRange = 5.0;
            break;
        case MATERIAL_BREWING_STAND:
            lightColor = vec3(0.636, 0.509, 0.179);
            lightRange = 3.0;
            break;
        case MATERIAL_FROGLIGHT_OCHRE:
            lightColor = vec3(0.702, 0.642, 0.349);
            lightRange = 15.0;
            break;
        case MATERIAL_FROGLIGHT_VERDANT:
            lightColor = vec3(0.463, 0.763, 0.409);
            lightRange = 15.0;
            break;
        case MATERIAL_FROGLIGHT_PEARLESCENT:
            lightColor = vec3(0.737, 0.435, 0.658);
            lightRange = 15.0;
            break;
        case MATERIAL_CRYING_OBSIDIAN:
            lightColor = vec3(0.390, 0.065, 0.646);
            lightRange = 10.0;
            //flicker = 0.3;
            break;
        case MATERIAL_CANDLES_1:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 3.0;
            flicker = 0.06;
            break;
        case MATERIAL_CANDLES_2:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 6.0;
            flicker = 0.06;
            break;
        case MATERIAL_CANDLES_3:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 9.0;
            flicker = 0.06;
            break;
        case MATERIAL_CANDLES_4:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 12.0;
            flicker = 0.06;
            break;
        case MATERIAL_SHROOMLIGHT:
            lightColor = vec3(0.848, 0.469, 0.205);
            lightRange = 15.0;
            break;
        case MATERIAL_BEACON:
            lightColor = vec3(1.0, 1.0, 1.0);
            lightRange = 15.0;
            break;
    }

    #ifdef LIGHT_FLICKER_ENABLED
        if (blockId == MATERIAL_TORCH || blockId == MATERIAL_LANTERN || blockId == MATERIAL_FIRE) {
            float torchTemp = mix(2600, 3400, 1.0 - flickerNoise);
            lightColor = blackbody(torchTemp);
        }

        if (blockId == MATERIAL_SOUL_TORCH) {
            float soulTorchTemp = mix(1200, 1800, flickerNoise);
            lightColor = 0.6 * saturate(1.0 - blackbody(soulTorchTemp));
        }

        if (blockId == MATERIAL_CANDLES_1 || blockId == MATERIAL_CANDLES_2
         || blockId == MATERIAL_CANDLES_3 || blockId == MATERIAL_CANDLES_4) {
            float candleTemp = mix(1900, 2400, 1.0 - flickerNoise);
            lightColor = 0.4 * blackbody(candleTemp);
        }
    #endif

    if (lightRange > EPSILON) {
        // if (blockId == MATERIAL_TORCH) {
        //     //vec3 texPos = worldPos.xzy * vec3(0.04, 0.04, 0.02);
        //     //texPos.z += 2.0 * time;

        //     //vec2 s = texture(TEX_CLOUD_NOISE, texPos).rg;

        //     //lightOffset = 0.08 * hash44(vec4(worldPos * 0.04, 2.0 * time)).xyz - 0.04;
        //     //lightOffset = 0.12 * hash44(vec4(worldPos * 0.04, 4.0 * time)).xyz - 0.06;
        // }

        #ifdef LIGHT_FLICKER_ENABLED
            if (flicker > EPSILON) {
                lightColor.rgb *= 1.0 - flicker * (1.0 - flickerNoise);
            }
        #endif

        AddSceneLight(blockLocalPos + lightOffset, lightRange, vec4(lightColor, 1.0));
    }
}