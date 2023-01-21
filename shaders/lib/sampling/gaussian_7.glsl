vec3 GaussianBlur13(const in sampler2D tex, const in vec2 uv, const in vec2 direction) {
    vec2 off1 = 1.411764705882353 * direction;
    vec2 off2 = 3.2941176470588234 * direction;
    vec2 off3 = 5.176470588235294 * direction;

    vec3 color = textureLod(tex, uv, 1).rgb * 0.1964825501511404;

    vec2 uv1 = uv + off1;
    color += textureLod(tex, uv1, 1).rgb * 0.2969069646728344;

    vec2 uv2 = uv - off1;
    color += textureLod(tex, uv2, 1).rgb * 0.2969069646728344;

    vec2 uv3 = uv + off2;
    color += textureLod(tex, uv3, 1).rgb * 0.09447039785044732;

    vec2 uv4 = uv - off2;
    color += textureLod(tex, uv4, 1).rgb * 0.09447039785044732;

    vec2 uv5 = uv + off3;
    color += textureLod(tex, uv5, 1).rgb * 0.010381362401148057;

    vec2 uv6 = uv - off3;
    color += textureLod(tex, uv6, 1).rgb * 0.010381362401148057;

    return color;
}
