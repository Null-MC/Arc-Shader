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

const float isotropicPhase = 0.25 / PI;

vec3 GetVolumetricSmoke(const in LightData lightData, inout vec3 transmittance, const in vec3 viewNear, const in vec3 viewFar) {
    vec3 viewRayVector = viewFar - viewNear;
    float viewRayLength = length(viewRayVector);
    if (viewRayLength < EPSILON) return vec3(0.0);

    const float stepF = rcp(VL_SAMPLES_SKY + 1.0);

    float stepLength = viewRayLength * stepF;
    vec3 rayStep = viewRayVector * stepF;
    //vec3 accumColor = vec3(0.0);
    //float accumF = 0.0;
    //float accumD = 0.0;

    vec3 fogColorLinear = RGBToLinear(fogColor);

    //float viewNearDist = length(viewNear);

    vec3 viewStart = viewNear;

    #ifdef VL_DITHER
        viewStart += rayStep * GetScreenBayerValue();
    #endif

    vec3 SmokeAbsorptionCoefficient = vec3(0.01);
    vec3 SmokeScatteringCoefficient = vec3(0.20);
    vec3 SmokeExtinctionCoefficient = SmokeScatteringCoefficient + SmokeAbsorptionCoefficient;

    // vec3 localPos = (gbufferModelViewInverse * vec4(viewStart, 1.0)).xyz;
    // vec3 viewPosPrev = (gbufferPreviousModelView * vec4(localPos + cameraPosition - previousCameraPosition, 1.0)).xyz;
    // vec3 clipPosPrev = unproject(gbufferPreviousProjection * vec4(viewPosPrev, 1.0));
    // vec2 lightTexcoord = clipPosPrev.xy * 0.5 + 0.5;

    vec2 viewSize = vec2(viewWidth, viewHeight);

    vec3 clipPos = unproject(gbufferProjection * vec4(viewNear, 1.0));
    vec2 lightTexcoord = clipPos.xy * 0.5 + 0.5;
    //lightTexcoord -= 0.5 * rcp(viewSize);
    vec3 t;

    int bloomTileCount = GetBloomTileCount();
    float time = frameTimeCounter / 3600.0;

    const float SmokeSpeed = 65.0;

    vec3 scattering = vec3(0.0);
    for (int i = 0; i < VL_SAMPLES_SKY; i++) {
        vec3 currentViewPos = viewStart + i * rayStep;
        vec3 localTracePos = (gbufferModelViewInverse * vec4(currentViewPos, 1.0)).xyz;

        vec3 worldTracePos = cameraPosition + localTracePos;

        //vec3 sampleAmbient = 60.0 * fogColorLinear;

        t = worldTracePos / 128.0;
        t.xz -= time * 4.0 * SmokeSpeed;
        float texDensity1 = texture(colortex13, t).r;

        t = worldTracePos / 64.0;
        t.xz += time * 2.0 * SmokeSpeed;
        float texDensity2 = texture(colortex13, t).r;

        t = worldTracePos / 32.0;
        t.y += time * 1.0 * SmokeSpeed;
        float texDensity3 = texture(colortex13, t).r;

        float texDensity = 0.4 * texDensity1 * texDensity2 + 0.6 * pow3(texDensity3);
        //float texDensity = pow(0.4 * texDensity1 + 0.6 * texDensity2, 4.0);

        vec3 stepTransmittance = exp(-SmokeExtinctionCoefficient * stepLength * texDensity);
        vec3 scatteringIntegral = (1.0 - stepTransmittance) / SmokeExtinctionCoefficient;

        float viewDistF = 1.0 - saturate(length(currentViewPos) / fogEnd);
        float lod = 2.0 + viewDistF * max(bloomTileCount - 4, 0);

        vec2 lodTexcoord = lightTexcoord - 0.5 * rcp(viewSize) * exp2(lod);

        vec3 lightColor1 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(0, 0)).rgb;
        vec3 lightColor2 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(1, 0)).rgb;
        vec3 lightColor3 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(0, 1)).rgb;
        vec3 lightColor4 = textureLodOffset(BUFFER_HDR_PREVIOUS, lodTexcoord, lod, ivec2(1, 1)).rgb;
        vec3 lightColor = 0.25 * (lightColor1 + lightColor2 + lightColor3 + lightColor4) / exposure;

        lightColor = 2.0 * lightColor + 20000.0 * fogColorLinear * stepF;

        //int bloomTile = 3;//clamp(int(viewDistF * bloomTileCount + 0.5), 0, bloomTileCount);

        //vec2 tileMin, tileMax;
        //GetBloomTileInnerBounds(bloomTile, tileMin, tileMax);

        //vec2 bloomTileTex = lightTexcoord * (tileMax - tileMin) + tileMin;
        //bloomTileTex = clamp(bloomTileTex, tileMin, tileMax);

        //vec3 lightColor = textureLod(BUFFER_BLOOM, bloomTileTex, 0).rgb;// / exposure;

        scattering += lightColor * (isotropicPhase * SmokeScatteringCoefficient * scatteringIntegral) * transmittance;

        transmittance *= stepTransmittance;
    }

    //scattering *= 8.0 * lightColor;//2000.0 * fogColorLinear;

    return scattering;
}
