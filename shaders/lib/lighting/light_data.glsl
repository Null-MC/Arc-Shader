struct PbrLightData {
    float blockLight;
    float skyLight;
    float geoNoL;
    float occlusion;

    float solidShadowDepth;
    float waterShadowDepth;

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        mat4 matShadowProjection[4];
        vec3 shadowPos[4];
    #else
        vec4 shadowPos;
    #endif
};
