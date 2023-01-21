vec3 GaussianBlur13(const in sampler2D tex, const in vec2 uv, const in vec2 tileMin, const in vec2 tileMax, const in vec2 direction) {
    vec2 off1 = 1.411764705882353 * direction;
    vec2 off2 = 3.2941176470588234 * direction;
    vec2 off3 = 5.176470588235294 * direction;

    vec3 color = textureLod(tex, uv, 0).rgb * 0.1964825501511404;

    vec2 uv1 = uv + off1;
    if (uv1.x < tileMax.x && uv1.y < tileMax.y)
        color += textureLod(tex, uv1, 0).rgb * 0.2969069646728344;

    vec2 uv2 = uv - off1;
    if (uv2.x > tileMin.x && uv2.y > tileMin.y)
        color += textureLod(tex, uv2, 0).rgb * 0.2969069646728344;

    vec2 uv3 = uv + off2;
    if (uv3.x < tileMax.x && uv3.y < tileMax.y)
        color += textureLod(tex, uv3, 0).rgb * 0.09447039785044732;

    vec2 uv4 = uv - off2;
    if (uv4.x > tileMin.x && uv4.y > tileMin.y)
        color += textureLod(tex, uv4, 0).rgb * 0.09447039785044732;

    vec2 uv5 = uv + off3;
    if (uv5.x < tileMax.x && uv5.y < tileMax.y)
        color += textureLod(tex, uv5, 0).rgb * 0.010381362401148057;

    vec2 uv6 = uv - off3;
    if (uv6.x > tileMin.x && uv6.y > tileMin.y)
        color += textureLod(tex, uv6, 0).rgb * 0.010381362401148057;

    return color;
}
