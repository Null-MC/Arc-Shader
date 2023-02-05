//#define DRAG_MULT 0.066

// returns vec2 with wave height in X and its derivative in Y
vec2 GetWaveDX(const in vec2 position, const in vec2 direction, const in float speed, const in float frequency, const in float timeshift) {
    float x = dot(direction, position) * frequency + timeshift * speed;
    float wave = exp(sin(x) - 1.0);
    float dx = wave * cos(x);
    return vec2(wave, -dx);
}

float GetWaveSpeed(const in float windSpeed, const in float skyLight) {
    return windSpeed * skyLight * 0.04;
}

float GetWaveDepth(const in float skyLight) {
    return mix(0.5, 1.0, rainStrength) * skyLight;
}

float hash11(in float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec3 GetWaves(const in vec2 position, const in float strength, const in int iterations) {
    float weight = 1.0;//max(waveSpeed, 0.3) + 0.1;
    float maxWeight = 0.0;//max(1.0 - 0.2*waveSpeed, 0.0);

    float dragF = 0.12 * strength;

    //float iter = 0.0;
    float speed = 7.4;
    float phase = 4.2;//2.0*PI;
    float accumWeight = 0.0;//maxWeight;

    float time = frameTimeCounter / 3.6;
    vec2 pos = position;

    for (int i = 0; i < iterations; i++) {
        float iter = 0.65 * hash11(i) * PI*2.0;

        vec2 direction = vec2(sin(iter), cos(iter));
        vec2 waveDX = GetWaveDX(pos, direction, speed, phase, time);
        pos += normalize(direction) * waveDX.y * weight * dragF;

        accumWeight += waveDX.x * weight;
        maxWeight += weight;

        //weight = mix(weight, 0.0, 0.17);
        weight *= 0.81;

        //iter += 12.0 + 9.58*i;
        phase *= 1.18;
        speed *= 1.09;
        dragF *= 0.85;
    }

    //float height = 0.84 - accumWeight / max(maxWeight, EPSILON);
    //return 1.0 - saturate(height * 1.32);
    return vec3(pos.x, accumWeight / max(maxWeight, EPSILON), pos.y);
}
