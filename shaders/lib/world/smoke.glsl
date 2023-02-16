const float isotropicPhase = 0.25 / PI;
const float SmokeSpeed = 18.0;


float SmokeFBM(vec3 texPos) {
    float accum = 0.0;
    float weight = 1.0;
    float maxWeight = 0.0;
    for (int i = 0; i < 4; i++) {
        float p = texture(TEX_CLOUD_NOISE, texPos).g;
        accum += p * weight;
        maxWeight += weight;

        texPos *= 2.2;
        weight *= 1.3;
    }

    return accum / maxWeight;
}

vec3 GetVolumetricSmoke(const in LightData lightData, inout vec3 transmittance, const in vec3 nearViewPos, const in vec3 farViewPos) {
    const float inverseStepCountF = rcp(SKY_VL_SAMPLES - 1);

    #ifdef VL_DITHER
        float dither = GetScreenBayerValue();
    #else
        const float dither = 0.0;
    #endif

    vec3 localStart = (gbufferModelViewInverse * vec4(nearViewPos, 1.0)).xyz;
    vec3 localEnd = (gbufferModelViewInverse * vec4(farViewPos, 1.0)).xyz;
    vec3 localRay = localEnd - localStart;
    float localRayLength = length(localRay);
    vec3 localStep = localRay * inverseStepCountF;

    float localStepLength = localRayLength * inverseStepCountF;

    if (localRayLength < EPSILON) return vec3(0.0);

    //vec3 fogColorLinear = vec3(1.0); //RGBToLinear(fogColor);
    vec3 lightColor = vec3(4.0 * FOG_AREA_LUMINANCE);// * fogColorLinear * inverseStepCountF;

    const vec3 SmokeAbsorptionCoefficientBase = 1.0 - vec3(0.529, 0.439, 0.369);
    vec3 SmokeScatteringCoefficientBase = fogColor;
    //vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);

    float time = frameTimeCounter / 3600.0;

    vec3 scattering = vec3(0.0);
    for (int i = 1; i < SKY_VL_SAMPLES; i++) {
        vec3 traceLocalPos = localStart + localStep * (i + dither);
        vec3 traceWorldPos = cameraPosition + traceLocalPos;

        vec3 traceTexPos = traceWorldPos.xzy * vec3(0.001, 0.001, 0.004);
        float texDensity = 1.0 - SmokeFBM(traceTexPos);
        texDensity = 0.5 * pow(texDensity, 4.0);// * SmokeDensityF;

        const vec3 SmokeAbsorptionCoefficient = texDensity * SmokeAbsorptionCoefficientBase;
        vec3 SmokeScatteringCoefficient = texDensity * SmokeScatteringCoefficientBase;
        vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

        vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * localStepLength);
        vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

        scattering += lightColor * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

        transmittance *= stepTransmittance;
    }

    return scattering;
}
