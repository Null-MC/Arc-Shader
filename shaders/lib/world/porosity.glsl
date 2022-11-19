// Wetness

float GetDirectionalWetness(const in vec3 normal, const in float skyLight) {
    vec3 viewUpDir = normalize(upPosition);
    float NoU = dot(normal, viewUpDir) * 0.5 + 0.5;
    float accum = saturate(8.0 * (0.96875 - skyLight));
    return saturate(wetness * smoothstep(-0.2, 1.0, NoU) - accum);
}

float GetSurfaceWetness(const in float wetness, const in float porosity) {
    return saturate(3.0*wetness - porosity);
}

vec3 WetnessDarkenSurface(const in vec3 albedo, const in float porosity, const in float wetness) {
    float f = wetness * porosity;
    return pow(albedo, vec3(1.0 + f)) * saturate(1.0 - f * POROSITY_DARKENING);
}

void ApplyWetness(inout PbrMaterial material, const in float skyLight) {
    vec3 waterLocalPos = cameraPosition + localPos;
    vec2 waterTex = waterLocalPos.xz + vec2(0.08, 0.02) * waterLocalPos.y;

    float noise1 = textureLod(noisetex, 0.01*waterTex, 0).r;
    float noise2 = 1.0 - textureLod(noisetex, 0.05*waterTex, 0).r;
    float noise3 = textureLod(noisetex, 0.20*waterTex, 0).r;

    float wetnessFinal = GetDirectionalWetness(material.normal, skyLight);

    if (wetnessFinal > EPSILON) {
        float areaWetness = saturate(biomeWetness * wetnessFinal * 
            (1.00 * noise1 + 0.50 * noise2 + 0.25 * noise3));

        material.albedo.rgb = WetnessDarkenSurface(material.albedo.rgb, material.porosity, areaWetness);

        float puddleF = smoothstep(0.7, 0.8, areaWetness);// * pow2(wetnessFinal);

        vec3 viewUpDir = normalize(upPosition);
        material.normal = mix(material.normal, viewUpDir, puddleF);
        material.normal = normalize(material.normal);
        
        float surfaceWetness = GetSurfaceWetness(areaWetness, material.porosity);
        surfaceWetness = max(surfaceWetness, puddleF);

        material.smoothness = mix(material.smoothness, WATER_SMOOTH, surfaceWetness);
        material.f0 = mix(material.f0, 0.02, surfaceWetness * (1.0 - material.f0));
    }
}

// Snow

float GetDirectionalSnow(const in vec3 normal, const in float skyLight) {
    vec3 viewUpDir = normalize(upPosition);
    float NoU = dot(normal, viewUpDir);
    float accum = saturate(4.0 * (0.96875 - skyLight));
    return saturate(smoothstep(-0.05, 0.6, NoU) - accum);
}

void ApplySnow(inout PbrMaterial material, const in float viewDist, const in float skyLight) {
    vec3 snowLocalPos = cameraPosition + localPos;
    vec2 snowTex = snowLocalPos.xz + snowLocalPos.y;

    float noise1 = 1.0 - textureLod(noisetex, 0.01*snowTex, 0).r;
    float noise2 = 1.0 - textureLod(noisetex, 0.05*snowTex, 0).r;
    float noise3 = textureLod(noisetex, 0.20*snowTex, 0).r;

    float snowFinal = GetDirectionalSnow(material.normal, skyLight);
    //snowFinal = min(snowFinal + (1.0 - occlusion), 1.0);

    float areaSnow = saturate(2.0 * snowFinal * biomeSnow *
        (1.00 * noise1 + 0.50 * noise2 + 0.25 * noise3));

    if (material.hcm < 0 || areaSnow > 0.2) {
        if (material.hcm >= 0) {
            material.hcm = -1;
            material.f0 = 0.04;
            material.albedo.rgb = SNOW_COLOR;
        }
        else {
            material.f0 = mix(material.f0, 0.04, areaSnow);
            material.albedo.rgb = mix(material.albedo.rgb, SNOW_COLOR, areaSnow);
        }

        vec2 localTex = (texcoord - atlasBounds[0]) * atlasSize;

        // TODO: offset by at_midBlock pos.xz+y for variation
        // localTex += ;

        vec3 snowNormal = normalize(hash32(uvec2(localTex)) * 2.0 - 1.0);
        snowNormal *= sign(dot(snowNormal, material.normal));

        float snowDistF = 1.0 - saturate(viewDist / 20.0);
        material.normal = normalize(mix(material.normal, snowNormal, 0.16 * snowDistF));

        float snowSmooth = 0.3 + 0.4 * hash12(uvec2(localTex));
        material.smoothness = mix(material.smoothness, snowSmooth, areaSnow);

        float snowScatter = 0.1 + 0.3 * hash12(uvec2(localTex));
        material.scattering = mix(material.scattering, snowScatter, areaSnow);
    }

    material.albedo.a = min(material.albedo.a + 4.0*areaSnow, 1.0);
}