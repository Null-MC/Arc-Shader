// vec3 GetScatteredLighting(const in float worldTraceHeight, const in vec2 skyLightLevels, const in vec2 scatteringF) {
//     #ifdef RENDER_DEFERRED
//         vec3 sunTransmittance = GetSunTransmittance(colortex7, worldTraceHeight, skyLightLevels.x);
//         vec3 moonTransmittance = GetMoonTransmittance(colortex7, worldTraceHeight, skyLightLevels.y);
//     #else
//         vec3 sunTransmittance = GetSunTransmittance(colortex9, worldTraceHeight, skyLightLevels.x);
//         vec3 moonTransmittance = GetMoonTransmittance(colortex9, worldTraceHeight, skyLightLevels.y);
//     #endif

//     return
//         scatteringF.x * sunTransmittance * sunColor * skyLightLevels.x +
//         scatteringF.y * moonTransmittance * GetMoonPhaseLevel() * moonColor * skyLightLevels.y;
// }

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

vec3 GetVolumetricSmoke(const in LightData lightData, inout vec3 transmittance, const in vec3 viewNear, const in vec3 viewFar) {
    vec3 viewRayVector = viewFar - viewNear;
    float viewRayLength = length(viewRayVector);
    if (viewRayLength < EPSILON) return vec3(0.0);

    const float stepF = rcp(VL_SAMPLES_SKY + 1.0);

    float stepLength = viewRayLength * stepF;
    vec3 rayStep = viewRayVector * stepF;

    vec3 fogColorLinear = RGBToLinear(fogColor);

    vec3 viewStart = viewNear;

    #ifdef VL_DITHER
        viewStart += rayStep * GetScreenBayerValue();
    #endif

    vec3 SmokeAbsorptionCoefficient = vec3(0.01);
    vec3 SmokeScatteringCoefficient = vec3(0.16);
    vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

    vec2 viewSize = vec2(viewWidth, viewHeight);

    vec3 clipPos = unproject(gbufferProjection * vec4(viewNear, 1.0));
    vec2 lightTexcoord = clipPos.xy * 0.5 + 0.5;
    vec3 t;

    vec2 blurScale = 6.0 * rcp(viewSize);

    //int bloomTileCount = GetBloomTileCount();
    float time = frameTimeCounter / 3600.0;

    const float SmokeSpeed = 65.0;

    vec3 scattering = vec3(0.0);
    for (int i = 0; i < VL_SAMPLES_SKY; i++) {
        vec3 currentViewPos = viewStart + i * rayStep;
        vec3 localTracePos = (gbufferModelViewInverse * vec4(currentViewPos, 1.0)).xyz;

        vec3 worldTracePos = cameraPosition + localTracePos;

        t = worldTracePos / 128.0;
        t.xz -= time * 4.0 * SmokeSpeed;
        float texDensity1 = texture(colortex13, t).r;

        t = worldTracePos / 64.0;
        t.xz += time * 2.0 * SmokeSpeed;
        float texDensity2 = texture(colortex13, t).r;

        t = worldTracePos / 32.0;
        t.y += time * 1.0 * SmokeSpeed;
        float texDensity3 = texture(colortex13, t).r;

        float texDensity = 0.4 * texDensity1 * texDensity2 + 0.6 * pow3(texDensity3 * texDensity2);

        vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * stepLength * texDensity);
        vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

        float viewDistF = saturate(length(currentViewPos) / fogEnd);
        viewDistF = pow2(1.0 - viewDistF);
        float lod = 2.0 + viewDistF * 4.0;

        vec2 lodTexcoord = lightTexcoord - 0.5 * rcp(viewSize) * exp2(lod);

        // vec3 lightColor1 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(0, 0)).rgb;
        // vec3 lightColor2 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(1, 0)).rgb;
        // vec3 lightColor3 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(0, 1)).rgb;
        // vec3 lightColor4 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(1, 1)).rgb;
        // vec3 lightColor = 0.25 * (lightColor1 + lightColor2 + lightColor3 + lightColor4) / exposure;

        vec3 lightColor = blur(BUFFER_HDR_PREVIOUS, lodTexcoord, blurScale, lod);

        lightColor = 8.0 * lightColor + 80000.0 * fogColorLinear * stepF;

        //int bloomTile = 3;//clamp(int(viewDistF * bloomTileCount + 0.5), 0, bloomTileCount);

        //vec2 tileMin, tileMax;
        //GetBloomTileInnerBounds(bloomTile, tileMin, tileMax);

        //vec2 bloomTileTex = lightTexcoord * (tileMax - tileMin) + tileMin;
        //bloomTileTex = clamp(bloomTileTex, tileMin, tileMax);

        //vec3 lightColor = textureLod(BUFFER_BLOOM, bloomTileTex, 0).rgb;// / exposure;

        scattering += lightColor * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

        transmittance *= stepTransmittance;
    }

    return scattering;
}
