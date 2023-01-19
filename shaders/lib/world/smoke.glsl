const float SmokeSpeed = 65.0;
const float isotropicPhase = 0.25 / PI;


float GetSmokeDensity(const in sampler3D tex, const in vec3 worldPos, const in float time) {
    t = worldPos / 128.0;
    t.xz -= time * 4.0 * SmokeSpeed;
    float texDensity1 = texture(tex, t).r;

    t = worldPos / 64.0;
    t.xz += time * 2.0 * SmokeSpeed;
    float texDensity2 = texture(tex, t).r;

    t = worldPos / 32.0;
    t.y += time * 1.0 * SmokeSpeed;
    float texDensity3 = texture(tex, t).r;

    return 0.4 * texDensity1 * texDensity2 + 0.6 * pow3(texDensity3 * texDensity2);
}

vec3 GetVolumetricSmoke(const in LightData lightData, inout vec3 transmittance, const in vec3 nearViewPos, const in vec3 farViewPos) {
    const float inverseStepCountF = rcp(VL_SAMPLES_SKY + 1);

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

    vec3 fogColorLinear = RGBToLinear(fogColor);
    vec3 ambient = 80000.0 * fogColorLinear * inverseStepCountF;

    vec3 SmokeAbsorptionCoefficient = vec3(0.01);
    vec3 SmokeScatteringCoefficient = vec3(0.16);
    vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);

    vec3 t;

    float time = frameTimeCounter / 3600.0;

    vec3 scattering = vec3(0.0);
    for (int i = 0; i < VL_SAMPLES_SKY; i++) {
        vec3 traceLocalPos = localStart + localStep * (i + dither);
        vec3 traceWorldPos = cameraPosition + traceLocalPos;

        #if SHADER_PLATFORM == PLATFORM_IRIS
            float texDensity = GetSmokeDensity(texCloudNoise, traceWorldPos, time);
        #else
            float texDensity = GetSmokeDensity(colortex14, traceWorldPos, time);
        #endif

        vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * localStepLength * texDensity);
        vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

        scattering += ambient * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

        transmittance *= stepTransmittance;
    }

    return scattering;
}
