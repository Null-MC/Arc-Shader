// localCoord: local texture coordinate [0-1]
// atlasBounds: [0]=position [1]=size
vec2 GetAtlasCoord(const in vec2 localCoord) {
    return fract(localCoord) * atlasBounds[1] + atlasBounds[0];
}

vec2 GetLocalCoord(const in vec2 atlasCoord) {
    return (atlasCoord - atlasBounds[0]) / max(atlasBounds[1], EPSILON);
}
