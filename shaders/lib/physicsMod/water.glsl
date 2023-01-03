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

    // this is the surface detail from the physics options, ranges from 13 to 48 (yeah I know weird)
    uniform int physics_iterationsNormal;

    // used to offset the 0 point of wave meshes to keep the wave function consistent even
    // though the mesh totally changes
    uniform vec2 physics_waveOffset;

    // time in seconds that can go faster dependent on weather conditions (affected by weather strength
    // multiplier in ocean settings
    uniform float physics_gameTime;

    // base value is 13 and gets multiplied by wave height in ocean settings
    uniform float physics_oceanHeight;

    // basic texture to determine how shallow/far away from the shore the water is
    uniform sampler2D physics_waviness;

    // basic scale for the horizontal size of the waves
    uniform float physics_oceanWaveHorizontalScale;
#endif

#ifdef RENDER_SHADOW
    #ifdef RENDER_VERTEX
        out vec3 physics_vLocalPosition;
    #endif

    #ifdef RENDER_GEOMETRY
        in vec3 physics_vLocalPosition[3];
        out vec3 physics_gLocalPosition;
    #endif

    #ifdef RENDER_FRAG
        in vec3 physics_gLocalPosition;
    #endif
#else
    #ifdef RENDER_VERTEX
        out vec3 physics_localPosition;
    #endif

    #ifdef RENDER_FRAG
        in vec3 physics_localPosition;
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
