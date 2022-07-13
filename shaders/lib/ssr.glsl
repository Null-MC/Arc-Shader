//#define MARCH_WORLD_SPACE
#define MARCH_SCREEN_SPACE

const float _MaxDistance = 15.0;
const float _Thickness = 0.0006;
const float _Step = 0.05;

// vec2 projectOnScreen(vec3 eye, vec3 point) {
//     vec3 toPoint = (point - eye);
//     point = (point - toPoint * (1.0 - near / dot(toPoint, CAMERA.Z)));
//     point -= eye + near * CAMERA.Z;
//     return point.xy;
// }

float map(float value, float min1, float max1, float min2, float max2) {
    return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

float GetReflectColor(const in vec2 uv, const in float depth, const in vec3 viewPos, const in vec3 reflectDir, out vec2 reflectionUV) {
    //vec2 uv = fragCoord.xy / iResolution.xy;
    ivec2 iuv = ivec2(uv * vec2(viewWidth, viewHeight));
    float specularMapR = texelFetch(BUFFER_SPECULAR, iuv, 0).r;
    
    // We sample the Depth (Buffer A), the normal (Buffer B)
    // And gather the view ray intersection
    
    float aspect = viewWidth / viewHeight;
    
    // ===== VIEW RAY =====
    // no idea what these are...
    vec3 CAMERA;
    vec3 EYE_POS;
    vec2 fragCoord;
    float iTime;

    vec3 eye = EYE_POS + vec3(3.0 * cos(iTime), 1.0 * sin(iTime), 0.0);
    // Pixel coordinates mapped to [-aspectRatio, aspectRatio] x [-1, 1]
    vec2 r_uv = 2.0 * fragCoord / viewHeight - vec2(aspect, 1.0);
    vec3 r_dir = vec3(r_uv.x * CAMERA.x + r_uv.y * CAMERA.y + near * CAMERA.z);
    // ====================
    
    //float depth = texture(iChannel0, uv).x;
    //vec3 normal = texture(iChannel1, uv).xyz;
    
    
    vec3 view = normalize(r_dir) * length(r_dir) * depth * far / near;
    vec3 position = eye + view;
    //vec3 reflected = reflect(normalize(view), normal);
    
    reflectionUV = uv;
    float atten = 0.0f;
    
    #ifdef MARCH_SCREEN_SPACE
        // ===== Project onto screen space =====
        // The camera projection-view matrix here (_ProjectionView * position)
        vec4 projEndPos = gbufferProjection * vec4(viewPos + reflectDir, 1.0);

        vec2 screenStart = uv;//projectOnScreen(eye, position);
        vec2 screenEnd = projEndPos.xy / projEndPos.w; //projectOnScreen(eye, position + reflectDir);
        vec2 screenDir = (screenEnd - screenStart).xy;
    
        // ===== Ray march in screen space =====
        float reflectedDepth = dot(reflectDir, CAMERA.z) / far;
        float depthStep = reflectedDepth;

        float currentDepth = depth;
        vec2 march = screenStart;

        for (float i = 0.0; i < _MaxDistance; i += _Step) {
            march += screenDir * _Step;
            vec2 marchUV;
            marchUV.x = map(march.x, -aspect, aspect, 0.0, 1.0); 
            marchUV.y = map(march.y, -1.0, 1.0, 0.0, 1.0); 
            float targetDepth = textureLod(depthtex0, marchUV, 0).x;
            float depthDiff = currentDepth - targetDepth;

            if (depthDiff > 0.0 && depthDiff < depthStep) {
                reflectionUV = marchUV;
                atten = 1.0 - i / _MaxDistance;
                break;
            }

            currentDepth += depthStep * _Step;
        }
    #endif

    #ifdef MARCH_WORLD_SPACE
        vec3 marchReflection;
        float currentDepth = depth;
        for (float i = _Step; i < _MaxDistance; i += _Step) {
            marchReflection = i * reflectDir;
            float targetDepth = dot(view + marchReflection, CAMERA.Z) / far;
            vec2 target = projectOnScreen(eye, position + marchReflection);
            target.x = map(target.x, -aspect, aspect, 0.0, 1.0); 
            target.y = map(target.y, -1.0, 1.0, 0.0, 1.0); 
            float sampledDepth = texture(iChannel0, target).x;
            float depthDiff = sampledDepth - currentDepth;

            if (depthDiff > 0.0 && depthDiff < targetDepth - currentDepth + _Thickness) {
                reflectionUV = target;
                atten = 1.0 - i / _MaxDistance;
                break;
            }

            currentDepth = targetDepth;

            if (currentDepth > 1.0) {
                atten = 1.0;
                break;
            }
        }
    #endif

    //return texture(iChannel2, reflectionUV).rgb * atten + col.rgb;
    return atten;
}
