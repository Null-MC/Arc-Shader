float Gaussian(const in float sigma, const in float x) {
    return exp(-pow2(x) / (2.0 * pow2(sigma)));
}

float BilateralGaussianDepthBlur_9x(const in sampler2D blendSampler, const in vec2 blendTexSize, const in sampler2D depthSampler, const in vec2 depthTexSize, const in float linearDepth, const in float sigmaV, const in int comp) {
    float g_sigmaV = 0.03 * pow2(sigmaV) + 0.001;

    float g_sigmaX = 3.0;
    float g_sigmaY = 3.0;

    const float c_halfSamplesX = 4.0;
    const float c_halfSamplesY = 4.0;

    float total = 0.0;
    float accum = 0.0;

    vec2 blendPixelSize = rcp(blendTexSize);
    
    for (float iy = -c_halfSamplesY; iy <= c_halfSamplesY; iy++) {
        float fy = Gaussian(g_sigmaY, iy);

        for (float ix = -c_halfSamplesX; ix <= c_halfSamplesX; ix++) {
            float fx = Gaussian(g_sigmaX, ix);
            
            vec2 sampleTex = texcoord + vec2(ix, iy) * blendPixelSize;

            ivec2 iTexBlend = ivec2(sampleTex * blendTexSize);
            float sampleValue = texelFetch(blendSampler, iTexBlend, 0)[comp];

            ivec2 iTexDepth = ivec2(sampleTex * depthTexSize);
            float sampleDepth = texelFetch(depthSampler, iTexDepth, 0).r;
            float sampleLinearDepth = linearizeDepthFast(sampleDepth, near, far);
            
            float fv = Gaussian(g_sigmaV, abs(sampleLinearDepth - linearDepth));
            
            float weight = fx*fy*fv;
            accum += weight * sampleValue;
            total += weight;
        }
    }
    
    //if (total <= EPSILON) return 1.0;
    return accum / total;
}

float BilateralGaussianDepthBlur_9x(const in sampler2D blendSampler, const in vec2 blendTexSize, const in sampler2D depthSampler, const in vec2 depthTexSize, const in float linearDepth, const in float sigmaV) {
    return BilateralGaussianDepthBlur_9x(blendSampler, blendTexSize, depthSampler, depthTexSize, linearDepth, sigmaV, 0);
}

float BilateralGaussianDepthBlur_7x(const in sampler2D blendSampler, const in vec2 blendTexSize, const in sampler2D depthSampler, const in vec2 depthTexSize, const in float linearDepth, const in vec3 g_sigma, const in int comp) {
    const float c_halfSamplesX = 3.0;
    const float c_halfSamplesY = 3.0;

    float total = 0.0;
    float accum = 0.0;

    vec2 blendPixelSize = rcp(blendTexSize);
    vec2 depthPixelSize = rcp(depthTexSize);
    
    for (float iy = -c_halfSamplesY; iy <= c_halfSamplesY; iy++) {
        float fy = Gaussian(g_sigma.y, iy);

        for (float ix = -c_halfSamplesX; ix <= c_halfSamplesX; ix++) {
            float fx = Gaussian(g_sigma.x, ix);
            
            vec2 sampleTex = texcoord + vec2(ix, iy) * blendPixelSize;

            //ivec2 iTexBlend = ivec2(sampleTex * blendTexSize);
            float sampleValue = textureLod(blendSampler, sampleTex, 0)[comp];

            vec2 sampleDepthTex = texcoord + vec2(ix, iy) * depthPixelSize;
            ivec2 iTexDepth = ivec2(sampleDepthTex * depthTexSize);
            float sampleDepth = texelFetch(depthSampler, iTexDepth, 0).r;

            float handClipDepth = texelFetch(depthtex2, iTexDepth, 0).r;
            if (handClipDepth > sampleDepth) {
                sampleDepth = sampleDepth * 2.0 - 1.0;
                sampleDepth /= MC_HAND_DEPTH;
                sampleDepth = sampleDepth * 0.5 + 0.5;
            }

            float sampleLinearDepth = linearizeDepthFast(sampleDepth, near, far);
                        
            float fv = Gaussian(g_sigma.z, abs(sampleLinearDepth - linearDepth));
            
            float weight = fx*fy*fv;
            accum += weight * sampleValue;
            total += weight;
        }
    }
    
    if (total < EPSILON) return 0.0;
    return accum / total;
}

vec3 BilateralGaussianDepthBlurRGB_7x(const in sampler2D blendSampler, const in vec2 blendTexSize, const in sampler2D depthSampler, const in vec2 depthTexSize, const in float linearDepth, const in vec3 g_sigma) {
    const float c_halfSamplesX = 3.0;
    const float c_halfSamplesY = 3.0;

    float total = 0.0;
    vec3 accum = vec3(0.0);

    vec2 blendPixelSize = rcp(blendTexSize);
    vec2 depthPixelSize = rcp(depthTexSize);
    
    for (float iy = -c_halfSamplesY; iy <= c_halfSamplesY; iy++) {
        float fy = Gaussian(g_sigma.y, iy);

        for (float ix = -c_halfSamplesX; ix <= c_halfSamplesX; ix++) {
            float fx = Gaussian(g_sigma.x, ix);
            
            vec2 sampleTex = texcoord + vec2(ix, iy) * blendPixelSize;
            vec3 sampleValue = textureLod(blendSampler, sampleTex, 0).rgb;

            vec2 sampleDepthTex = texcoord + vec2(ix, iy) * depthPixelSize;
            ivec2 iTexDepth = ivec2(sampleDepthTex * depthTexSize);
            float sampleDepth = texelFetch(depthSampler, iTexDepth, 0).r;

            float handClipDepth = texelFetch(depthtex2, iTexDepth, 0).r;
            if (handClipDepth > sampleDepth) {
                sampleDepth = sampleDepth * 2.0 - 1.0;
                sampleDepth /= MC_HAND_DEPTH;
                sampleDepth = sampleDepth * 0.5 + 0.5;
            }

            float sampleLinearDepth = linearizeDepthFast(sampleDepth, near, far);
            
            float fv = Gaussian(g_sigma.z, abs(sampleLinearDepth - linearDepth));
            
            float weight = fx*fy*fv;
            accum += weight * sampleValue;
            total += weight;
        }
    }
    
    if (total <= EPSILON) return vec3(0.0);
    return accum / total;
}

vec4 BilateralGaussianDepthBlurRGBA_7x(const in sampler2D blendSampler, const in vec2 blendTexSize, const in sampler2D depthSampler, const in vec2 depthTexSize, const in float linearDepth, const in vec3 g_sigma) {
    const float c_halfSamplesX = 3.0;
    const float c_halfSamplesY = 3.0;

    float total = 0.0;
    vec4 accum = vec4(0.0);

    vec2 blendPixelSize = rcp(blendTexSize);
    vec2 depthPixelSize = rcp(depthTexSize);
    
    for (float iy = -c_halfSamplesY; iy <= c_halfSamplesY; iy++) {
        float fy = Gaussian(g_sigma.y, iy);

        for (float ix = -c_halfSamplesX; ix <= c_halfSamplesX; ix++) {
            float fx = Gaussian(g_sigma.x, ix);
            
            vec2 sampleTex = texcoord + vec2(ix, iy) * blendPixelSize;
            vec4 sampleValue = textureLod(blendSampler, sampleTex, 0);

            vec2 sampleDepthTex = texcoord + vec2(ix, iy) * depthPixelSize;
            ivec2 iTexDepth = ivec2(sampleDepthTex * depthTexSize);
            float sampleDepth = texelFetch(depthSampler, iTexDepth, 0).r;

            float handClipDepth = texelFetch(depthtex2, iTexDepth, 0).r;
            if (handClipDepth > sampleDepth) {
                sampleDepth = sampleDepth * 2.0 - 1.0;
                sampleDepth /= MC_HAND_DEPTH;
                sampleDepth = sampleDepth * 0.5 + 0.5;
            }
            
            float sampleLinearDepth = linearizeDepthFast(sampleDepth, near, far);
                        
            float fv = Gaussian(g_sigma.z, abs(sampleLinearDepth - linearDepth));
            
            float weight = fx*fy*fv;
            accum += weight * sampleValue;
            total += weight;
        }
    }
    
    if (total < EPSILON) return vec4(0.0);
    return accum / total;
}
