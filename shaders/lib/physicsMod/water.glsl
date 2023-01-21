// https://github.com/haubna/PhysicsMod/blob/main/oceans.glsl

#ifndef RENDER_GEOMETRY
    const int PHYSICS_ITERATIONS_OFFSET = 13;
    const float PHYSICS_DRAG_MULT = 0.048;
    const float PHYSICS_XZ_SCALE = 0.035;
    const float PHYSICS_TIME_MULTIPLICATOR = 0.45;
    const float PHYSICS_W_DETAIL = 0.75;
    const float PHYSICS_FREQUENCY = 6.0;
    const float PHYSICS_SPEED = 2.0;
    const float PHYSICS_WEIGHT = 0.8;
    const float PHYSICS_FREQUENCY_MULT = 1.18;
    const float PHYSICS_SPEED_MULT = 1.07;
    const float PHYSICS_ITER_INC = 12.0;
    const float PHYSICS_NORMAL_STRENGTH = 0.6;

    uniform int physics_iterationsNormal;
    uniform vec2 physics_waveOffset;
    uniform ivec2 physics_textureOffset;
    uniform float physics_gameTime;
    uniform float physics_oceanHeight;
    uniform sampler2D physics_waviness;
    uniform float physics_oceanWaveHorizontalScale;
#endif

#ifdef RENDER_SHADOW
    #ifdef RENDER_VERTEX
        out vec3 physics_vLocalPosition;
        out float physics_vLocalWaviness;
    #endif

    #ifdef RENDER_GEOMETRY
        in vec3 physics_vLocalPosition[3];
        in float physics_vLocalWaviness[3];
        out vec3 physics_gLocalPosition;
        out float physics_gLocalWaviness;
    #endif

    #ifdef RENDER_FRAG
        in vec3 physics_gLocalPosition;
        in float physics_gLocalWaviness;
    #endif
#else
    #ifdef RENDER_VERTEX
        out vec3 physics_localPosition;
        out float physics_localWaviness;
    #endif

    #ifdef RENDER_FRAG
        in vec3 physics_localPosition;
        in float physics_localWaviness;
    #endif
#endif

#ifdef RENDER_VERTEX
    float physics_waveHeight(const in vec3 position, const in float iterations, const in float factor, const in float time) {
        vec2 wavePos = (position.xz - physics_waveOffset) * PHYSICS_XZ_SCALE * physics_oceanWaveHorizontalScale;
    	float iter = 0.0;
        float frequency = PHYSICS_FREQUENCY;
        float speed = PHYSICS_SPEED;
        float weight = 1.0;
        float height = 0.0;
        float waveSum = 0.0;
        float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
        
        for (int i = 0; i < iterations; i++) {
            vec2 direction = vec2(sin(iter), cos(iter));
            float x = dot(direction, wavePos) * frequency + modifiedTime * speed;
            float wave = exp(sin(x) - 1.0);
            float result = wave * cos(x);
            vec2 force = result * weight * direction;
            
            wavePos -= force * PHYSICS_DRAG_MULT;
            height += wave * weight;
            iter += PHYSICS_ITER_INC;
            waveSum += weight;
            weight *= PHYSICS_WEIGHT;
            frequency *= PHYSICS_FREQUENCY_MULT;
            speed *= PHYSICS_SPEED_MULT;
        }
        
        return height / waveSum * physics_oceanHeight * factor - physics_oceanHeight * factor * 0.5;
    }

    float physics_waveHeight(const in vec3 position, const in float factor, const in float time) {
        return physics_waveHeight(position, PHYSICS_ITERATIONS_OFFSET, factor, time);
    }
#endif

#ifdef RENDER_FRAG
    vec2 physics_waveDirection(const in vec2 position, const in float iterations, const in float time) {
        vec2 wavePos = (position - physics_waveOffset) * PHYSICS_XZ_SCALE * physics_oceanWaveHorizontalScale;
    	float iter = 0.0;
        float frequency = PHYSICS_FREQUENCY;
        float speed = PHYSICS_SPEED;
        float weight = 1.0;
        float waveSum = 0.0;
        float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
        vec2 dx = vec2(0.0);
        
        for (int i = 0; i < iterations; i++) {
            vec2 direction = vec2(sin(iter), cos(iter));
            float x = dot(direction, wavePos) * frequency + modifiedTime * speed;
            float wave = exp(sin(x) - 1.0);
            float result = wave * cos(x);
            vec2 force = result * weight * direction;
            
            dx += force / pow(weight, PHYSICS_W_DETAIL); 
            wavePos -= force * PHYSICS_DRAG_MULT;
            iter += PHYSICS_ITER_INC;
            waveSum += weight;
            weight *= 0.8;
            frequency *= PHYSICS_FREQUENCY_MULT;
            speed *= PHYSICS_SPEED_MULT;
        }
        
        return vec2(dx / pow(waveSum, 1.0 - PHYSICS_W_DETAIL));
    }

    vec3 physics_waveNormal(const in vec2 position, const in float factor, const in float time, const in float iterations) {
        vec2 wave = -physics_waveDirection(position, iterations, time);
        float oceanHeightFactor = physics_oceanHeight / 13.0;
        float totalFactor = oceanHeightFactor * factor;
        return normalize(vec3(wave.x * totalFactor, PHYSICS_NORMAL_STRENGTH, wave.y * totalFactor));
    }

    vec3 physics_waveNormal(const in vec2 position, const in float factor, const in float time) {
        return physics_waveNormal(position, factor, time, physics_iterationsNormal);
    }
#endif
