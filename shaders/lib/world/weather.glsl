// Wetness

vec3 WetnessDarkenSurface(const in vec3 albedo, const in float porosity, const in float wetness) {
    float f = pow(wetness, 0.5) * porosity * PorosityDarkeningF;
    return pow(albedo, vec3(1.0 + f)) * saturate(1.0 - f);
}

#if !defined RENDER_ENTITIES && !defined RENDER_HAND && !defined RENDER_HAND_WATER
    void ApplyWetness(inout PbrMaterial material, const in float weatherNoise, const in float NoU, const in float skyLight) {
        if (skyWetnessSmooth < EPSILON && biomeWetnessSmooth < EPSILON) return;

        float upF = smoothstep(-0.2, 1.0, NoU);
        float accum = saturate(8.0 * (0.96875 - skyLight));
        //float skyWetness = saturate(upF - accum);

        float o = 0.3 * skyWetnessSmooth;
        float skyAreaWetness = saturate(upF - accum) * (weatherNoise + o) * skyWetnessSmooth * (1.0 - o);
        //skyAreaWetness = pow(skyAreaWetness, 0.5);

        #if WETNESS_MODE == WEATHER_MODE_FULL
            float biomeAreaWetness = upF * saturate(weatherNoise - (1.0 - biomeWetnessSmooth)) * biomeWetnessSmooth;
            float totalAreaWetness = saturate(max(biomeAreaWetness, skyAreaWetness));
        #else
            float totalAreaWetness = saturate(skyAreaWetness);
        #endif

        if (totalAreaWetness < EPSILON) return;
        //totalAreaWetness = pow(totalAreaWetness, 0.5);

        material.albedo.rgb = WetnessDarkenSurface(material.albedo.rgb, material.porosity, totalAreaWetness);
        
        float surfaceWetness = saturate(2.0 * totalAreaWetness - material.porosity);

        float puddleF = smoothstep(0.65, 0.75, surfaceWetness) * max(NoU, EPSILON);// * pow2(wetnessFinal);
        surfaceWetness = max(surfaceWetness, puddleF);

        material.normal = mix(material.normal, vec3(0.0, 0.0, 1.0), surfaceWetness);
        material.normal = normalize(material.normal);

        material.smoothness = mix(material.smoothness, WATER_SMOOTH, surfaceWetness);
        material.f0 = mix(material.f0, 0.02, surfaceWetness * (1.0 - material.f0));
    }

    // Snow

    void ApplySnow(inout PbrMaterial material, const in float weatherNoise, const in float NoU, const in float viewDist, const in float blockLight, const in float skyLight) {
        float accum = saturate(2.0 * (0.96875 - skyLight));
        float snowFinal = saturate(smoothstep(-0.1, 0.4, NoU));
        snowFinal = pow(snowFinal, 0.5);
        
        float blockLightFalloff = saturate(4.0 * (blockLight - 0.75));

        float skySnowFinal = snowFinal * skySnowSmooth * smoothstep(1.0 - skySnowSmooth, 1.0, saturate(weatherNoise - accum - blockLightFalloff));

        #if SNOW_MODE == WEATHER_MODE_FULL
            float biomeSnowFinal = snowFinal * biomeSnowSmooth * smoothstep(1.0 - biomeSnowSmooth, 1.0, saturate(weatherNoise - accum - blockLightFalloff));
            float totalSnow = max(biomeSnowFinal, skySnowFinal);
        #else
            float totalSnow = skySnowFinal;
        #endif

        if (totalSnow < EPSILON) return;

        vec3 snowColor = RGBToLinear(mix(SNOW_COLOR, POWDER_SNOW_COLOR, totalSnow));

        if (material.hcm >= 0) {
            material.hcm = -1;
            material.f0 = 0.04;
            material.albedo.rgb = snowColor;
        }
        else {
            material.f0 = mix(material.f0, 0.04, totalSnow);
            material.albedo.rgb = mix(material.albedo.rgb, snowColor, totalSnow);
        }

        vec2 localTex = (texcoord - atlasBounds[0]) * atlasSize;

        // TODO: offset by at_midBlock pos.xz+y for variation
        // localTex += ;

        vec3 worldPos = cameraPosition + localPos;
        vec3 snowPos = vec3(worldPos.xz, worldPos.y + 0.12*weatherNoise);

        vec3 snowDX = dFdx(snowPos);
        vec3 snowDY = dFdy(snowPos);
        if (!all(lessThan(abs(snowDX), vec3(EPSILON))) && !all(lessThan(abs(snowDY), vec3(EPSILON)))) {
            float s = smoothstep(0.7, 0.9, totalSnow * 2.0 * max(NoU - 0.5, 0.0));
            material.normal = mix(material.normal, normalize(cross(snowDY, snowDX)), s);
        }

        vec3 snowNormal = normalize(hash32(uvec2(localTex)) * 2.0 - 1.0);
        snowNormal *= sign(dot(snowNormal, material.normal));

        float snowDistF = 1.0 - saturate(viewDist / 20.0);
        material.normal = normalize(mix(material.normal, snowNormal, 0.16 * totalSnow * snowDistF));

        float smoothNoise = hash12(uvec2(localTex));
        float snowSmooth = 0.16 + 0.64 * pow4(smoothNoise); // TODO: add random offset
        material.smoothness = mix(material.smoothness, snowSmooth, totalSnow);

        float snowScatter = 0.2 + 0.2 * hash12(uvec2(localTex)); // TODO: add random offset
        material.scattering = mix(material.scattering, snowScatter, totalSnow);

        material.albedo.a = min(material.albedo.a + totalSnow, 1.0);
    }

    void ApplyWeather(inout PbrMaterial material, const in float NoU, const in float viewDist, const in float blockLight, const in float skyLight) {
        vec3 worldPos = cameraPosition + localPos;
        vec2 weatherTex = worldPos.xz + worldPos.y;

        float noise1 = texture(noisetex, 0.01*weatherTex).r;
        float noise2 = 1.0 - texture(noisetex, 0.05*weatherTex).r;
        float noise3 = texture(noisetex, 0.20*weatherTex).r;

        float weatherNoise = noise1 + 0.6 * noise2 + 0.4 * noise3;

        #if WETNESS_MODE != WEATHER_MODE_NONE
            ApplyWetness(material, weatherNoise, NoU, skyLight);
        #endif

        #if SNOW_MODE != WEATHER_MODE_NONE
            if (skySnowSmooth > EPSILON || biomeSnowSmooth > EPSILON)
                ApplySnow(material, weatherNoise, NoU, viewDist, blockLight, skyLight);
        #endif
    }
#endif
