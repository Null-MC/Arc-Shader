struct LightData {
    float parallaxShadow;
    float occlusion;
    float blockLight;
    float skyLight;
    float geoNoL;

    vec2 skyLightLevels;
    vec3 sunTransmittance;
    vec3 moonTransmittance;
    vec3 sunTransmittanceEye;
    vec3 moonTransmittanceEye;

    float opaqueScreenDepth;
    float opaqueScreenDepthLinear;
    float transparentScreenDepth;
    float transparentScreenDepthLinear;
    //float waterScreenDepth;

    float opaqueShadowDepth;
    float transparentShadowDepth;
    float waterShadowDepth;


    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        //mat4 matShadowProjection[4];
        //vec2 shadowProjectionSize[4];
        vec3 shadowPos[4];

        float shadowBias[4];
        //vec2 shadowTilePos[4];
        int shadowCascade;
    #else
        vec4 shadowPos;
        float shadowBias;
    #endif
};
