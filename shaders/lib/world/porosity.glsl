// Wetness

vec3 WetnessDarkenSurface(const in vec3 albedo, const in float porosity, const in float wetness) {
    float f = pow(wetness, 0.5) * porosity * POROSITY_DARKENING;
    return pow(albedo, vec3(1.0 + f)) * saturate(1.0 - f);
}

#if !defined RENDER_ENTITIES && !defined RENDER_HAND && !defined RENDER_HAND_WATER
    void ApplyWetness(inout PbrMaterial material, const in float NoU, const in float skyLight) {
        if (skyWetnessSmooth < EPSILON && biomeWetnessSmooth < EPSILON) return;

        vec3 waterLocalPos = cameraPosition + localPos;
        vec2 waterTex = waterLocalPos.xz + vec2(0.08, 0.02) * waterLocalPos.y;

        float noise1 = textureLod(noisetex, 0.01*waterTex, 0).r;
        float noise2 = 1.0 - textureLod(noisetex, 0.05*waterTex, 0).r;
        float noise3 = textureLod(noisetex, 0.20*waterTex, 0).r;

        float areaWetness = 1.00 * noise1 + 0.50 * noise2 + 0.25 * noise3;

        //vec3 viewUpDir = normalize(upPosition);
        //float NoU = dot(material.normal, viewUpDir);
        float upF = smoothstep(-0.2, 1.0, NoU);

        float accum = saturate(8.0 * (0.96875 - skyLight));
        float skyWetness = saturate(upF - accum);

        float skyAreaWetness = saturate(saturate(upF - accum) * areaWetness * skyWetnessSmooth);

        #if WETNESS_MODE == WEATHER_MODE_FULL
            float biomeAreaWetness = upF * saturate(areaWetness - biomeWetnessSmooth) * biomeWetnessSmooth;
            float totalAreaWetness = max(biomeAreaWetness, skyAreaWetness);
        #else
            float totalAreaWetness = skyAreaWetness;
        #endif

        if (totalAreaWetness < EPSILON) return;

        material.albedo.rgb = WetnessDarkenSurface(material.albedo.rgb, material.porosity, totalAreaWetness);

        float puddleF = smoothstep(0.7, 0.8, totalAreaWetness) * max(NoU, EPSILON);// * pow2(wetnessFinal);

        material.normal = mix(material.normal, vec3(0.0, 0.0, 1.0), puddleF);
        material.normal = normalize(material.normal);
        
        float surfaceWetness = saturate(3.0*totalAreaWetness - material.porosity);
        surfaceWetness = max(surfaceWetness, puddleF);

        material.smoothness = mix(material.smoothness, WATER_SMOOTH, surfaceWetness);
        material.f0 = mix(material.f0, 0.02, surfaceWetness * (1.0 - material.f0));
    }

    // Snow

    void ApplySnow(inout PbrMaterial material, const in float NoU, const in float viewDist, const in float blockLight, const in float skyLight) {
        if (skySnowSmooth < EPSILON && biomeSnowSmooth < EPSILON) return;

        vec3 snowLocalPos = cameraPosition + localPos;
        vec2 snowTex = snowLocalPos.xz + snowLocalPos.y;

        float noise1 = texture(noisetex, 0.01*snowTex).r;
        float noise2 = 1.0 - texture(noisetex, 0.05*snowTex).r;
        float noise3 = texture(noisetex, 0.20*snowTex).r;

        float areaSnow = 1.00 * noise1 + 0.50 * noise2 + 0.25 * noise3;

        //float snowFinal = GetDirectionalSnow(material.normal, skyLight);
        //snowFinal = min(snowFinal + (1.0 - occlusion), 1.0);


        //vec3 viewUpDir = normalize(upPosition);
        //float NoU = dot(material.normal, tanUpDir);
        float accum = saturate(2.0 * (0.96875 - skyLight));
        float snowFinal = saturate(smoothstep(-0.1, 0.4, NoU));
        snowFinal = pow(snowFinal, 0.5);

        float skySnowFinal = snowFinal * skySnowSmooth * smoothstep(1.0 - skySnowSmooth, 1.0, saturate(areaSnow - accum));

        #if SNOW_MODE == WEATHER_MODE_FULL
            float blockLightFalloff = saturate(4.0 * (blockLight - 0.75));
            float biomeSnowFinal = snowFinal * biomeSnowSmooth * smoothstep(1.0 - biomeSnowSmooth, 1.0, saturate(areaSnow - accum - blockLightFalloff));
            float totalSnow = max(biomeSnowFinal, skySnowFinal);
        #else
            float totalSnow = skySnowFinal;
        #endif

        //totalSnow = smoothstep(0.5, 1.0, totalSnow);
        //totalSnow = pow(totalSnow, 0.4);

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

        vec3 snowPos = vec3(snowLocalPos.xz, snowLocalPos.y + 0.4*areaSnow);

        vec3 snowDX = dFdx(snowPos);
        vec3 snowDY = dFdy(snowPos);
        if (!all(lessThan(abs(snowDX), vec3(EPSILON))) && !all(lessThan(abs(snowDY), vec3(EPSILON))))
            material.normal = mix(material.normal, normalize(cross(snowDY, snowDX)), totalSnow * 2.0 * max(NoU - 0.5, 0.0));

        vec3 snowNormal = normalize(hash32(uvec2(localTex)) * 2.0 - 1.0);
        snowNormal *= sign(dot(snowNormal, material.normal));

        float snowDistF = 1.0 - saturate(viewDist / 20.0);
        material.normal = normalize(mix(material.normal, snowNormal, 0.24 * totalSnow * snowDistF));

        float smoothNoise = hash12(uvec2(localTex));
        float snowSmooth = 0.16 + 0.64 * pow4(smoothNoise); // TODO: add random offset
        material.smoothness = mix(material.smoothness, snowSmooth, totalSnow);

        float snowScatter = 0.2 + 0.2 * hash12(uvec2(localTex)); // TODO: add random offset
        material.scattering = mix(material.scattering, snowScatter, totalSnow);

        material.albedo.a = min(material.albedo.a + totalSnow, 1.0);
    }
#endif
