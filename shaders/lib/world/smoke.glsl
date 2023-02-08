const float isotropicPhase = 0.25 / PI;
const float SmokeSpeed = 18.0;


float GetSmokeDensity(const in sampler3D tex, const in vec3 worldPos, const in float time) {
    vec3 t;

    t = worldPos / 128.0;
    t.xz -= time * 4.0 * SmokeSpeed;
    float texDensity1 = textureLod(tex, t, 0).r;

    t = worldPos / 64.0;
    t.xz += time * 2.0 * SmokeSpeed;
    float texDensity2 = textureLod(tex, t, 0).r;

    t = worldPos / 32.0;
    t.y += time * 1.0 * SmokeSpeed;
    float texDensity3 = textureLod(tex, t, 0).r;

    return 0.4 * texDensity1 * texDensity2 + 0.6 * pow3(texDensity3 * texDensity2);
}

vec3 GetVolumetricSmoke(const in LightData lightData, inout vec3 transmittance, const in vec3 nearViewPos, const in vec3 farViewPos) {
    const float inverseStepCountF = rcp(SKY_VL_SAMPLES + 1);

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

    vec3 fogColorLinear = vec3(1.0); //RGBToLinear(fogColor);
    vec3 ambient = 20000.0 * fogColorLinear * inverseStepCountF;

    const vec3 SmokeAbsorptionCoefficient = 1.0 - vec3(0.529, 0.439, 0.369);
    vec3 SmokeScatteringCoefficient = RGBToLinear(fogColor);
    vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);

    float time = frameTimeCounter / 3600.0;

    vec3 scattering = vec3(0.0);
    for (int i = 0; i < SKY_VL_SAMPLES; i++) {
        vec3 traceLocalPos = localStart + localStep * (i + dither);
        vec3 traceWorldPos = cameraPosition + traceLocalPos;

        float texDensity = GetSmokeDensity(TEX_CLOUD_NOISE, traceWorldPos, time);

        texDensity = pow(texDensity, 3.0) * VL_SMOKE_DENSITY;

        vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * localStepLength * texDensity);
        vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

        scattering += ambient * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

        transmittance *= stepTransmittance;
    }

    return scattering;
}
