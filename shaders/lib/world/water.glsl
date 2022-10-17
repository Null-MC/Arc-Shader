#define DRAG_MULT 0.048

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

float GetWaves(inout vec2 position, const in float waveSpeed, const in int iterations) {
    float weight = max(waveSpeed, 0.4);
    float maxWeight = max(1.0 - 0.2*waveSpeed, 0.0);

    float iter = 0.0;
    float speed = 6.0;
    float phase = PI;
    float accumWeight = maxWeight;

    float time = frameTimeCounter / 3.6;

    for (int i = 0; i < iterations; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        vec2 waveDX = GetWaveDX(position, direction, speed, phase, time);
        position += normalize(direction) * waveDX.y * weight * DRAG_MULT;

        accumWeight += waveDX.x * weight;
        maxWeight += weight;

        weight = mix(weight, 0.0, 0.18);

        iter += 12.0;
        phase *= 1.18;
        speed *= 1.07;
    }

    return accumWeight / max(maxWeight, EPSILON);
}
