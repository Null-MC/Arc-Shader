void AddSceneBlockLight(const in int blockId, const in vec3 blockLocalPos) {
    vec3 lightColor = vec3(0.0);
    vec3 lightOffset = vec3(0.0);
    float lightRange = 0.0;

    float flicker = 0.0;
    //float pulse = 0.0;
    float glow = 0.0;

    #ifdef LIGHT_FLICKER_ENABLED
        float time = frameTimeCounter / 3600.0;
        vec3 worldPos = cameraPosition + blockLocalPos;

        vec3 texPos = fract(worldPos.xzy * vec3(0.04, 0.04, 0.08));
        texPos.z += 1000.0 * time;

        vec2 noiseSample = texture(TEX_CLOUD_NOISE, texPos).rg;
        float flickerNoise = (1.0 - noiseSample.g) * (1.0 - pow2(noiseSample.r));
    #endif

    switch (blockId) {
        case BLOCK_AMETHYST_BUD_LARGE:
            lightColor = vec3(0.611, 0.396, 0.869);
            lightRange = 4.0;
            glow = 0.2;
            break;
        case BLOCK_AMETHYST_BUD_MEDIUM:
            lightColor = vec3(0.611, 0.396, 0.869);
            lightRange = 2.0;
            glow = 0.2;
            break;
        case BLOCK_AMETHYST_CLUSTER:
            lightColor = vec3(0.537, 0.412, 0.765);
            lightRange = 5.0;
            glow = 0.2;
            break;
        case BLOCK_BEACON:
            lightColor = vec3(1.0, 1.0, 1.0);
            lightRange = 15.0;
            break;
        case BLOCK_BLAST_FURNACE_LIT:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightOffset = vec3(0.0, -0.4, 0.0);
            lightRange = 6.0;
            break;
        case BLOCK_BREWING_STAND:
            lightColor = vec3(0.636, 0.509, 0.179);
            lightRange = 1.0;
            break;
        case BLOCK_CANDLES_LIT_1:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 3.0;
            flicker = 0.14;
            break;
        case BLOCK_CANDLES_LIT_2:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 6.0;
            flicker = 0.14;
            break;
        case BLOCK_CANDLES_LIT_3:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 9.0;
            flicker = 0.14;
            break;
        case BLOCK_CANDLES_LIT_4:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 12.0;
            flicker = 0.14;
            break;
        case BLOCK_CANDLE_CAKE_LIT:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightOffset = vec3(0.0, 0.4, 0.0);
            lightRange = 3.0;
            flicker = 0.14;
            break;
        case BLOCK_CAVEVINE_BERRIES:
            lightColor = 0.4 * vec3(0.717, 0.541, 0.188);
            lightRange = 14.0;
            break;
        case BLOCK_CRYING_OBSIDIAN:
            lightColor = vec3(0.390, 0.065, 0.646);
            lightRange = 10.0;
            glow = 0.3;
            break;
        case BLOCK_END_ROD:
            lightColor = vec3(0.957, 0.929, 0.875);
            lightRange = 14.0;
            break;
        case BLOCK_FIRE:
            lightColor = vec3(0.851, 0.616, 0.239);
            lightOffset = vec3(0.0, -0.3, 0.0);
            lightRange = 15.0;
            flicker = 0.3;
            break;
        case BLOCK_FROGLIGHT_OCHRE:
            lightColor = vec3(0.702, 0.642, 0.349);
            lightRange = 15.0;
            glow = 0.2;
            break;
        case BLOCK_FROGLIGHT_VERDANT:
            lightColor = vec3(0.463, 0.763, 0.409);
            lightRange = 15.0;
            glow = 0.2;
            break;
        case BLOCK_FROGLIGHT_PEARLESCENT:
            lightColor = vec3(0.737, 0.435, 0.658);
            lightRange = 15.0;
            glow = 0.2;
            break;
        case BLOCK_FURNACE_LIT:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightOffset = vec3(0.0, -0.2, 0.0);
            lightRange = 6.0;
            break;
        case BLOCK_GLOWSTONE:
            lightColor = vec3(0.652, 0.583, 0.275);
            lightRange = 15.0;
            glow = 0.4;
            break;
        case BLOCK_GLOW_LICHEN:
            lightColor = vec3(0.332, 0.495, 0.367);
            lightRange = 7.0;
            glow = 0.2;
            break;
        case BLOCK_JACK_O_LANTERN:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightRange = 15.0;
            flicker = 0.3;
            break;
        case BLOCK_LANTERN:
            lightColor = vec3(0.906, 0.737, 0.451);
            lightOffset = vec3(0.0, -0.25, 0.0);
            lightRange = 12.0;
            flicker = 0.05;
            break;
        case BLOCK_LAVA:
            #ifndef LIGHT_LAVA_ENABLED
                return;
            #endif
        case BLOCK_LAVA_CAULDRON:
            lightColor = vec3(0.804, 0.424, 0.149);
            lightRange = 15.0;
            glow = 0.4;
            break;
        case BLOCK_LIGHTNING_ROD_POWERED:
            lightColor = vec3(0.870, 0.956, 0.975);
            lightRange = 8.0;
            flicker = 0.8;
            break;
        case BLOCK_MAGMA:
            lightColor = vec3(0.804, 0.424, 0.149);
            lightRange = 3.0;
            glow = 0.2;
            break;
        case BLOCK_NETHER_PORTAL:
            lightColor = vec3(0.502, 0.165, 0.831);
            lightRange = 11.0;
            glow = 0.8;
            break;
        case BLOCK_REDSTONE_LAMP:
            lightColor = vec3(0.953, 0.796, 0.496);
            lightRange = 15.0;
            break;
        case BLOCK_REDSTONE_TORCH:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightRange = 7.0;
            break;
        case BLOCK_REDSTONE_WIRE_1:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 0.4;
            break;
        case BLOCK_REDSTONE_WIRE_2:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 0.6;
            break;
        case BLOCK_REDSTONE_WIRE_3:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 0.8;
            break;
        case BLOCK_REDSTONE_WIRE_4:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 1.0;
            break;
        case BLOCK_REDSTONE_WIRE_5:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 1.2;
            break;
        case BLOCK_REDSTONE_WIRE_6:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 1.4;
            break;
        case BLOCK_REDSTONE_WIRE_7:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 1.6;
            break;
        case BLOCK_REDSTONE_WIRE_8:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 1.8;
            break;
        case BLOCK_REDSTONE_WIRE_9:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 2.0;
            break;
        case BLOCK_REDSTONE_WIRE_10:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 2.2;
            break;
        case BLOCK_REDSTONE_WIRE_11:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 2.4;
            break;
        case BLOCK_REDSTONE_WIRE_12:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 2.6;
            break;
        case BLOCK_REDSTONE_WIRE_13:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 2.8;
            break;
        case BLOCK_REDSTONE_WIRE_14:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 3.0;
            break;
        case BLOCK_REDSTONE_WIRE_15:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.46, 0.0);
            lightRange = 3.2;
            break;
        case BLOCK_REPEATER_POWERED:
            lightColor = vec3(0.697, 0.130, 0.051);
            lightOffset = vec3(0.0, -0.2, 0.0);
            lightRange = 4.0;
            break;
        case BLOCK_RESPAWN_ANCHOR_4:
            lightColor = vec3(0.390, 0.065, 0.646);
            lightOffset = vec3(0.0, 0.4, 0.0);
            lightRange = 15.0;
            glow = 0.6;
            break;
        case BLOCK_RESPAWN_ANCHOR_3:
            lightColor = vec3(0.390, 0.065, 0.646);
            lightOffset = vec3(0.0, 0.4, 0.0);
            lightRange = 11.0;
            glow = 0.6;
            break;
        case BLOCK_RESPAWN_ANCHOR_2:
            lightColor = vec3(0.390, 0.065, 0.646);
            lightOffset = vec3(0.0, 0.4, 0.0);
            lightRange = 7.0;
            glow = 0.6;
            break;
        case BLOCK_RESPAWN_ANCHOR_1:
            lightColor = vec3(0.390, 0.065, 0.646);
            lightOffset = vec3(0.0, 0.4, 0.0);
            lightRange = 3.0;
            glow = 0.6;
            break;
        case BLOCK_SCULK_CATALYST:
            lightColor = vec3(0.510, 0.831, 0.851);
            lightOffset = vec3(0.0, 0.4, 0.0);
            lightRange = 6.0;
            break;
        case BLOCK_SEA_LANTERN:
            lightColor = vec3(0.635, 0.909, 0.793);
            lightRange = 15.0;
            glow = 0.4;
            break;
        case BLOCK_SHROOMLIGHT:
            lightColor = vec3(0.848, 0.469, 0.205);
            lightRange = 15.0;
            glow = 0.6;
            break;
        case BLOCK_SMOKER_LIT:
            lightColor = vec3(0.697, 0.654, 0.458);
            lightOffset = vec3(0.0, -0.3, 0.0);
            lightRange = 6.0;
            break;
        case BLOCK_SOUL_LANTERN:
            lightColor = vec3(0.510, 0.831, 0.851);
            lightOffset = vec3(0.0, -0.25, 0.0);
            lightRange = 12.0;
            flicker = 0.1;
            break;
        case BLOCK_SOUL_TORCH:
            lightColor = vec3(0.510, 0.831, 0.851);
            lightRange = 12.0;
            flicker = 0.1;
            break;
        case BLOCK_TORCH:
            lightColor = vec3(0.934, 0.771, 0.395);
            lightOffset = vec3(0.0, 0.4, 0.0);
            lightRange = 12.0;
            flicker = 0.4;
            break;
    }

    #ifdef LIGHT_FLICKER_ENABLED
        // TODO: optimize branching

        if (blockId == BLOCK_TORCH || blockId == BLOCK_LANTERN || blockId == BLOCK_FIRE) {
            float torchTemp = mix(3000, 4000, flickerNoise);
            lightColor = 0.8 * blackbody(torchTemp);
        }

        if (blockId == BLOCK_SOUL_TORCH || blockId == BLOCK_SOUL_LANTERN) {
            float soulTorchTemp = mix(1200, 1800, 1.0 - flickerNoise);
            lightColor = 0.8 * saturate(1.0 - blackbody(soulTorchTemp));
        }

        if (blockId == BLOCK_CANDLES_LIT_1 || blockId == BLOCK_CANDLES_LIT_2
         || blockId == BLOCK_CANDLES_LIT_3 || blockId == BLOCK_CANDLES_LIT_4
         || blockId == BLOCK_CANDLE_CAKE_LIT || blockId == BLOCK_JACK_O_LANTERN) {
            float candleTemp = mix(2600, 3600, flickerNoise);
            lightColor = 0.7 * blackbody(candleTemp);
        }
    #endif

    if (lightRange < EPSILON) return;

    bool intersects = true;
    #ifdef DYN_LIGHT_FRUSTUM_TEST
        vec3 lightViewPos = (gbufferModelView * vec4(blockLocalPos, 1.0)).xyz;

        if (lightViewPos.z > lightRange) intersects = false;
        else if (lightViewPos.z < -far - lightRange) intersects = false;
        else {
            if (dot(sceneViewUp,   lightViewPos) > lightRange) intersects = false;
            if (dot(sceneViewDown, lightViewPos) > lightRange) intersects = false;
            if (dot(sceneViewLeft,  lightViewPos) > lightRange) intersects = false;
            if (dot(sceneViewRight, lightViewPos) > lightRange) intersects = false;
        }
    #endif

    if (intersects) {
        // if (blockId == BLOCK_TORCH) {
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

            if (glow > EPSILON) {
                float cycle = sin(fract(time * 1000.0) * TAU) * 0.5 + 0.5;
                lightColor.rgb *= 1.0 - glow * smoothstep(0.0, 1.0, noiseSample.r);
            }
        #endif

        lightColor = RGBToLinear(lightColor);
        AddSceneLight(blockLocalPos + lightOffset, lightRange + 0.5, vec4(lightColor, 1.0));
    }
}