#ifdef RENDER_DEFERRED
    PbrMaterial PopulateMaterial(const in vec3 colorMap, const in vec4 normalMap, const in vec4 specularMap) {
        PbrMaterial material;
        material.albedo.rgb = RGBToLinear(colorMap);
        material.albedo.a = 1.0;
        material.normal.xyz = normalMap.rgb * 2.0 - 1.0;
        material.occlusion = normalMap.a;
        material.smoothness = specularMap.r;
        material.f0 = specularMap.g * step(specularMap.g, 0.9);
        //material.hcm = max(int(floor(specularMap.g * 255.0 - 229.5)), -1);
        material.hcm = int(floor(specularMap.g * 255.0 - 229.5));
        material.porosity = specularMap.b * 4.0 * step(specularMap.b, 0.25);
        material.scattering = max(specularMap.b - 0.25, 0.0) * (1.0 / 0.75);
        material.emission = specularMap.a * step(specularMap.a, 1.0 - EPSILON);

        if (material.f0 < EPSILON) material.f0 = 0.04;

        return material;
    }
#else
    void PopulateMaterial(const in vec2 atlasCoord, out PbrMaterial material) {
    	vec4 colorMap = texture2D(texture, atlasCoord) * glcolor;
    	vec4 normalMap = texture2D(normals, atlasCoord);
    	vec4 specularMap = texture2D(specular, atlasCoord);

    	material.albedo.rgb = RGBToLinear(colorMap.rgb);
    	material.albedo.a = colorMap.a;

        if (material.normal.x < EPSILON && material.normal.y < EPSILON)
            material.normal = vec3(0.0, 0.0, 1.0);
        else {
        	material.normal.xy = normalMap.xy * 2.0 - 1.0;
        	material.normal.z = sqrt(max(1.0 - dot(normalMap.xy, normalMap.xy), EPSILON));
        }

    	material.occlusion = normalMap.b;
    	material.smoothness = specularMap.r;
    	material.f0 = specularMap.g * step(specularMap.g, 0.9);
    	//material.hcm = int(max(specularMap.g * 255.0 - 229.5, -0.5));
        material.hcm = int(floor(specularMap.g * 255.0 - 229.5));
    	material.porosity = specularMap.b * 4.0 * step(specularMap.b, 0.25);
    	material.scattering = max(specularMap.b - 0.25, 0.0) * (1.0 / 0.75);
    	material.emission = specularMap.a * step(specularMap.a, 1.0 - EPSILON);

    	if (material.f0 < EPSILON) material.f0 = 0.04;
    }
#endif
