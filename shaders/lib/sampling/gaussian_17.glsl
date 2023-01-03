vec3 GaussianBlur23(const in sampler2D tex, const in vec2 uv, const in vec2 direction) {
    vec3 color = 0.041312 * textureLod(tex, uv, 0).rgb;

    color += 0.026109 * textureLod(tex, uv - 15.5 * direction, 0).rgb;
    color += 0.034202 * textureLod(tex, uv - 13.5 * direction, 0).rgb;
    color += 0.043219 * textureLod(tex, uv - 11.5 * direction, 0).rgb;
    color += 0.052683 * textureLod(tex, uv -  9.5 * direction, 0).rgb;
    color += 0.061948 * textureLod(tex, uv -  7.5 * direction, 0).rgb;
    color += 0.070266 * textureLod(tex, uv -  5.5 * direction, 0).rgb;
    color += 0.076883 * textureLod(tex, uv -  3.5 * direction, 0).rgb;
    color += 0.081149 * textureLod(tex, uv -  1.5 * direction, 0).rgb;
    color += 0.081149 * textureLod(tex, uv +  1.5 * direction, 0).rgb;
    color += 0.076883 * textureLod(tex, uv +  3.5 * direction, 0).rgb;
    color += 0.070266 * textureLod(tex, uv +  5.5 * direction, 0).rgb;
    color += 0.061948 * textureLod(tex, uv +  7.5 * direction, 0).rgb;
    color += 0.052683 * textureLod(tex, uv +  9.5 * direction, 0).rgb;
    color += 0.043219 * textureLod(tex, uv + 11.5 * direction, 0).rgb;
    color += 0.034202 * textureLod(tex, uv + 13.5 * direction, 0).rgb;
    color += 0.026109 * textureLod(tex, uv + 15.5 * direction, 0).rgb;

    return color / 0.93423;
}
