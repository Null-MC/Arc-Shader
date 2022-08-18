struct PbrLightData {
    float occlusion;
    float blockLight;
    float skyLight;
    float geoNoL;

    float parallaxShadow;
    float solidShadowDepth;
    float waterShadowDepth;

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        mat4 matShadowProjection[4];
        vec3 shadowPos[4];

        float shadowBias[4];
        vec2 shadowTilePos[4];
    #else
        vec4 shadowPos;
        float shadowBias;
    #endif
};
