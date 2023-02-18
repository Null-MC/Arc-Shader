struct LightData {
    float parallaxShadow;
    float occlusion;
    float blockLight;
    float skyLight;
    float geoNoL;
    vec3 geoNormal;

    //vec2 skyLightLevels;
    vec3 sunTransmittance;
    vec3 moonTransmittance;
    // vec3 sunTransmittanceEye;
    // vec3 moonTransmittanceEye;

    float opaqueScreenDepth;
    float opaqueScreenDepthLinear;
    float transparentScreenDepth;
    float transparentScreenDepthLinear;

    float opaqueShadowDepth;
    float transparentShadowDepth;
    float waterShadowDepth;

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        vec3 shadowPos[4];
        float shadowBias[4];
        int shadowCascade;
    #else
        vec3 shadowPos;
        float shadowBias;
    #endif
};
