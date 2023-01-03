const int samples = 12;
const float pi = atan(1.0) * 4.0;
const float sigma = float(samples) * 0.25;
const float isotropicPhase = 0.25 / PI;

float gaussian(const in vec2 i) {
    return 1.0 / (2.0 * pi * pow2(sigma)) * exp(-((pow2(i.x) + pow2(i.y)) / (2.0 * pow2(sigma))));
}

vec3 blur(sampler2D sp, vec2 uv, vec2 scale, float lod) {
    vec3 col = vec3(0.0);
    float accum = 0.0;
    float weight;
    vec2 offset;
    
    for (int x = -samples / 2; x < samples / 2; ++x) {
        for (int y = -samples / 2; y < samples / 2; ++y) {
            offset = vec2(x, y);
            weight = gaussian(offset);
            col += textureLod(sp, uv + scale * offset, lod).rgb * weight;
            accum += weight;
        }
    }
    
    return col / accum;
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
    //vec3 worldStart = localStart + cameraPosition;





    //vec3 viewRayVector = viewFar - viewNear;
    //float viewRayLength = length(viewRayVector);
    if (localRayLength < EPSILON) return vec3(0.0);

    //const float stepF = rcp(VL_SAMPLES_SKY + 1.0);

    //float stepLength = viewRayLength * stepF;
    //vec3 rayStep = viewRayVector * stepF;

    vec3 fogColorLinear = RGBToLinear(fogColor);

    //vec3 viewStart = viewNear;

    //#ifdef VL_DITHER
    //    viewStart += rayStep * GetScreenBayerValue();
    //#endif

    vec3 SmokeAbsorptionCoefficient = vec3(0.01);
    vec3 SmokeScatteringCoefficient = vec3(0.16);
    vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);

    vec3 clipPos = unproject(gbufferProjection * vec4(nearViewPos, 1.0));
    vec2 lightTexcoord = clipPos.xy * 0.5 + 0.5;
    vec3 t;

    //vec2 blurScale = 6.0 * rcp(viewSize);

    float time = frameTimeCounter / 3600.0;

    const float SmokeSpeed = 65.0;

    vec3 scattering = vec3(0.0);
    for (int i = 0; i < VL_SAMPLES_SKY; i++) {
        vec3 traceLocalPos = localStart + localStep * (i + dither);
        vec3 traceWorldPos = cameraPosition + traceLocalPos;

        t = traceWorldPos / 128.0;
        t.xz -= time * 4.0 * SmokeSpeed;
        float texDensity1 = texture(colortex13, t).r;

        t = traceWorldPos / 64.0;
        t.xz += time * 2.0 * SmokeSpeed;
        float texDensity2 = texture(colortex13, t).r;

        t = traceWorldPos / 32.0;
        t.y += time * 1.0 * SmokeSpeed;
        float texDensity3 = texture(colortex13, t).r;

        float texDensity = 0.4 * texDensity1 * texDensity2 + 0.6 * pow3(texDensity3 * texDensity2);

        vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * localStepLength * texDensity);
        vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

        float viewDistF = saturate(length(traceLocalPos) / fogEnd);
        viewDistF = pow2(1.0 - viewDistF);
        float lod = 2.0 + viewDistF * 4.0;

        vec2 lodTexcoord = lightTexcoord - 0.5 * pixelSize * exp2(lod);

        //vec3 lightColor = blur(BUFFER_HDR_PREVIOUS, lodTexcoord, blurScale, lod);
        vec3 lightColor = textureLod(BUFFER_HDR_PREVIOUS, lodTexcoord, lod).rgb / exposure;

        lightColor = 8.0 * lightColor + 80000.0 * fogColorLinear * inverseStepCountF;

        scattering += lightColor * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

        transmittance *= stepTransmittance;
    }

    return scattering;
}
