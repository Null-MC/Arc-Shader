#define TONEMAP_HejlBurgess 1
#define TONEMAP_AcesFilm 2
#define TONEMAP_Reinhard 3
#define TONEMAP_ReinhardJodie 4
#define TONEMAP_Uncharted2 5
#define TONEMAP_ACESFit 6
#define TONEMAP_ACESFit2 7
#define TONEMAP_FilmicHejl2015 8
#define TONEMAP_Burgess 9
#define TONEMAP_BurgessModified 11
#define TONEMAP_ReinhardExtendedLuminance 10
#define TONEMAP_Tech 12

#define TONEMAP TONEMAP_ACESFit2


//====  Stuff from Jessie ====//

vec3 tonemap_HejlBurgess(const in vec3 color)
{
    const float f = 1.0 / 1.1;

    const vec3 t = max(vec3(0.0), color * f - 0.0008);
    return color * (6.2 * t + 0.5) / (t * (6.2 * t + 1.7) + 0.06);
}

vec3 tonemap_AcesFilm(const in vec3 color)
{
    return clamp(color * (2.51 * color + 0.03) / (color * (2.43 * color + 0.59) + 0.14), 0.0, 1.0);
}


//====  Stuff from Tech ====//

//static const vec3 luma_factor = vec3(0.2126f, 0.7152f, 0.0722f);
//
//
//float luminance(const in vec3 color)
//{
//    return dot(color, luma_factor);
//}

vec3 tonemap_Reinhard(const in vec3 color)
{
    return color / (1.0 + color);
}

vec3 tonemap_ReinhardJodie(const in vec3 color)
{
    float luma = luminance(color);
    vec3 tonemapped_color = color / (1.0 + color);
    return mix(color / (1.0 + luma), tonemapped_color, tonemapped_color);
}

vec3 tonemap_Uncharted2(const in vec3 x)
{
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;

    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 tonemap_ACESFit(const in vec3 x)
{
    const float a = 1.9;
    const float b = 0.04;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;

    return clamp(x * (a * x+b) / (x * (c*x + d) + e), 0.0, 1.0);
}

// Based on http://www.oscars.org/science-technology/sci-tech-projects/aces
vec3 tonemap_ACESFit2(const in vec3 color){
    const mat3 m1 = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777);

    const mat3 m2 = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602);

    vec3 v = m1 * color;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return pow(clamp(m2 * (a / b), 0.0, 1.0), vec3(1.0 / 2.2));
}

vec3 tonemap_FilmicHejl2015(const in vec3 hdr, const in float whitePoint)
{
    vec4 vh = vec4(hdr, whitePoint);    // pack: [r, g, b, w]
    vec4 va = 1.425 * vh + 0.05;
    vec4 vf = (vh * va + 0.004) / (vh * (va + 0.55) + 0.0491) - 0.0821;
    return vf.rgb / vf.www;
}

vec3 tonemap_Burgess(const in vec3 color)
{
    vec3 maxColor = max(color - 0.004, vec3(0.0));
    return maxColor * (6.2 * maxColor + 0.5) / (maxColor * (6.2 * maxColor + 1.7) + 0.06);
}

vec3 _ChangeLuma(const in vec3 c_in, const in float l_out)
{
    float l_in = luminance(c_in);
    return c_in * (l_out / l_in);
}

vec3 tonemap_ReinhardExtendedLuminance(const in vec3 color, const in float maxWhiteLuma)
{
    float luma_old = luminance(color);
    float numerator = luma_old * (1.0 + luma_old / (maxWhiteLuma * maxWhiteLuma));
    float luma_new = numerator / (1.0 + luma_old);
    return _ChangeLuma(color, luma_new);
}

// Original by Dawson Burgess
// Modified by: https://github.com/TechDevOnGithub/
vec3 tonemap_BurgessModified(const in vec3 color)
{
    vec3 max_color = color * min(vec3(1.0), 1.0 - exp(-1.0 / (luminance(color) * 0.1) * color));
    return max_color * (6.2 * max_color + 0.5) / (max_color * (6.2 * max_color + 1.7) + 0.06);
}

// My custom tonemap, feel free to use, make sure to give credit though :D
vec3 tonemap_Tech(const in vec3 color)
{
    vec3 a = color * min(vec3(1.0), 1.0 - exp(-1.0 / 0.038 * color));
    a = mix(a, color, color * color);
    return a / (a + 0.6);
}


//====  compile-time global switch ====//

vec3 ApplyTonemap(const in vec3 color)
{
#if TONEMAP == TONEMAP_HejlBurgess
    return tonemap_HejlBurgess(color);
#elif TONEMAP == TONEMAP_AcesFilm
    return tonemap_AcesFilm(color);
#elif TONEMAP == TONEMAP_Reinhard
    return tonemap_Reinhard(color);
#elif TONEMAP == TONEMAP_ReinhardJodie
    return tonemap_ReinhardJodie(color);
#elif TONEMAP == TONEMAP_Uncharted2
    return tonemap_Uncharted2(color);
#elif TONEMAP == TONEMAP_ACESFit
    return tonemap_ACESFit(color);
#elif TONEMAP == TONEMAP_ACESFit2
    return tonemap_ACESFit2(color);
#elif TONEMAP == TONEMAP_FilmicHejl2015
    return tonemap_FilmicHejl2015(color, 1.0);
#elif TONEMAP == TONEMAP_Burgess
    return tonemap_Burgess(color);
#elif TONEMAP == TONEMAP_BurgessModified
    return tonemap_BurgessModified(color);
#elif TONEMAP == TONEMAP_ReinhardExtendedLuminance
    return tonemap_ReinhardExtendedLuminance(color, 4.0);
#elif TONEMAP == TONEMAP_Tech
    return tonemap_Tech(color);
#endif
}
