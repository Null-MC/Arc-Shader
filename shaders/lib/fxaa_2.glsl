#define FXAA_EDGE_THRESHOLD_MIN 0.0312
#define FXAA_EDGE_THRESHOLD_MAX 0.125
#define FXAA_QUALITY(q) ((q) < 5 ? 1.0 : ((q) > 5 ? ((q) < 10 ? 2.0 : ((q) < 11 ? 4.0 : 8.0)) : 1.5))
#define FXAA_SUBPIXEL_QUALITY 0.9
#define FXAA_ITERATIONS 12


float sampleLuma(const in vec2 uv, const in float exposure) {
	float lum = textureLod(BUFFER_LUM_OPAQUE, uv, 0.0).r;
    return max(exp2(lum) - EPSILON, 0.0) * exposure;
}

// Performs FXAA post-process anti-aliasing as described in the Nvidia FXAA white paper and the associated shader code.
vec3 FXAA(const in vec2 uv, const in float exposure) {
	vec2 viewSize = vec2(viewWidth, viewHeight);
	vec2 inverseScreenSize = rcp(viewSize);

	vec3 colorCenter = textureLod(BUFFER_HDR_OPAQUE, uv, 0.0).rgb;
	
	// Luma at the current fragment
	float lumaCenter = luminance(colorCenter);
	
	// Luma at the four direct neighbours of the current fragment.
	float lumaDown  = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2( 0,-1)).r;
	float lumaUp    = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2( 0, 1)).r;
	float lumaLeft  = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2(-1, 0)).r;
	float lumaRight = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2( 1, 0)).r;
    lumaDown  = max(exp2(lumaDown)  - EPSILON, 0.0) * exposure;
    lumaUp    = max(exp2(lumaUp)    - EPSILON, 0.0) * exposure;
    lumaLeft  = max(exp2(lumaLeft)  - EPSILON, 0.0) * exposure;
    lumaRight = max(exp2(lumaRight) - EPSILON, 0.0) * exposure;
	
	// Find the maximum and minimum luma around the current fragment.
	float lumaMin = min(lumaCenter, min(min(lumaDown, lumaUp), min(lumaLeft, lumaRight)));
	float lumaMax = max(lumaCenter, max(max(lumaDown, lumaUp), max(lumaLeft, lumaRight)));
	
	// Compute the delta.
	float lumaRange = lumaMax - lumaMin;
	
	// If the luma variation is lower that a threshold (or if we are in a really dark area), we are not on an edge, don't perform any AA.
	if (lumaRange < max(FXAA_EDGE_THRESHOLD_MIN, lumaMax * FXAA_EDGE_THRESHOLD_MAX)) return colorCenter;
	
	// Query the 4 remaining corners lumas.
	float lumaDownLeft  = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2(-1,-1)).r;
	float lumaUpRight   = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2( 1, 1)).r;
	float lumaUpLeft    = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2(-1, 1)).r;
	float lumaDownRight = textureLodOffset(BUFFER_LUM_OPAQUE, uv, 0.0, ivec2( 1,-1)).r;
    lumaDownLeft  = max(exp2(lumaDownLeft)  - EPSILON, 0.0) * exposure;
    lumaUpRight   = max(exp2(lumaUpRight)   - EPSILON, 0.0) * exposure;
    lumaUpLeft    = max(exp2(lumaUpLeft)    - EPSILON, 0.0) * exposure;
    lumaDownRight = max(exp2(lumaDownRight) - EPSILON, 0.0) * exposure;
	
	// Combine the four edges lumas (using intermediary variables for future computations with the same values).
	float lumaDownUp = lumaDown + lumaUp;
	float lumaLeftRight = lumaLeft + lumaRight;
	
	// Same for corners
	float lumaLeftCorners = lumaDownLeft + lumaUpLeft;
	float lumaDownCorners = lumaDownLeft + lumaDownRight;
	float lumaRightCorners = lumaDownRight + lumaUpRight;
	float lumaUpCorners = lumaUpRight + lumaUpLeft;
	
	// Compute an estimation of the gradient along the horizontal and vertical axis.
	float edgeHorizontal = abs(-2.0 * lumaLeft + lumaLeftCorners)
		+ abs(-2.0 * lumaCenter + lumaDownUp ) * 2.0
		+ abs(-2.0 * lumaRight + lumaRightCorners);

	float edgeVertical = abs(-2.0 * lumaUp + lumaUpCorners)
		+ abs(-2.0 * lumaCenter + lumaLeftRight) * 2.0
		+ abs(-2.0 * lumaDown + lumaDownCorners);
	
	// Is the local edge horizontal or vertical ?
	bool isHorizontal = (edgeHorizontal >= edgeVertical);
	
	// Choose the step size (one pixel) accordingly.
	float stepLength = isHorizontal ? inverseScreenSize.y : inverseScreenSize.x;
	
	// Select the two neighboring texels lumas in the opposite direction to the local edge.
	float luma1 = isHorizontal ? lumaDown : lumaLeft;
	float luma2 = isHorizontal ? lumaUp : lumaRight;
	// Compute gradients in this direction.
	float gradient1 = luma1 - lumaCenter;
	float gradient2 = luma2 - lumaCenter;
	
	// Which direction is the steepest ?
	bool is1Steepest = abs(gradient1) >= abs(gradient2);
	
	// Gradient in the corresponding direction, normalized.
	float gradientScaled = 0.25 * max(abs(gradient1), abs(gradient2));
	
	// Average luma in the correct direction.
	float lumaLocalAverage = 0.0;
	if (is1Steepest) {
		// Switch the direction
		stepLength = - stepLength;
		lumaLocalAverage = 0.5 * (luma1 + lumaCenter);
	} else {
		lumaLocalAverage = 0.5 * (luma2 + lumaCenter);
	}
	
	// Shift UV in the correct direction by half a pixel.
	vec2 currentUv = uv;
	if (isHorizontal) {
		currentUv.y += stepLength * 0.5;
	} else {
		currentUv.x += stepLength * 0.5;
	}
	
	// Compute offset (for each iteration step) in the right direction.
	vec2 offset = isHorizontal ? vec2(inverseScreenSize.x, 0.0) : vec2(0.0, inverseScreenSize.y);
	// Compute UVs to explore on each side of the edge, orthogonally. The QUALITY allows us to step faster.
	vec2 uv1 = currentUv - offset * FXAA_QUALITY(0);
	vec2 uv2 = currentUv + offset * FXAA_QUALITY(0);
	
	// Read the lumas at both current extremities of the exploration segment, and compute the delta wrt to the local average luma.
	float lumaEnd1 = sampleLuma(uv1, exposure);
	float lumaEnd2 = sampleLuma(uv2, exposure);
	lumaEnd1 -= lumaLocalAverage;
	lumaEnd2 -= lumaLocalAverage;
	
	// If the luma deltas at the current extremities is larger than the local gradient, we have reached the side of the edge.
	bool reached1 = abs(lumaEnd1) >= gradientScaled;
	bool reached2 = abs(lumaEnd2) >= gradientScaled;
	bool reachedBoth = reached1 && reached2;
	
	// If the side is not reached, we continue to explore in this direction.
	if (!reached1) {
		uv1 -= offset * FXAA_QUALITY(1);
	}

	if (!reached2) {
		uv2 += offset * FXAA_QUALITY(1);
	}
	
	// If both sides have not been reached, continue to explore.
	if (!reachedBoth) {
		for (int i = 2; i < FXAA_ITERATIONS; i++) {
			// If needed, read luma in 1st direction, compute delta.
			if (!reached1) {
				lumaEnd1 = sampleLuma(uv1, exposure);
				lumaEnd1 = lumaEnd1 - lumaLocalAverage;
			}

			// If needed, read luma in opposite direction, compute delta.
			if (!reached2) {
				lumaEnd2 = sampleLuma(uv2, exposure);
				lumaEnd2 = lumaEnd2 - lumaLocalAverage;
			}

			// If the luma deltas at the current extremities is larger than the local gradient, we have reached the side of the edge.
			reached1 = abs(lumaEnd1) >= gradientScaled;
			reached2 = abs(lumaEnd2) >= gradientScaled;
			reachedBoth = reached1 && reached2;
			
			// If the side is not reached, we continue to explore in this direction, with a variable quality.
			if (!reached1) {
				uv1 -= offset * FXAA_QUALITY(i);
			}

			if (!reached2) {
				uv2 += offset * FXAA_QUALITY(i);
			}
			
			// If both sides have been reached, stop the exploration.
			if (reachedBoth) break;
		}
	}
	
	// Compute the distances to each side edge of the edge (!).
	float distance1 = isHorizontal ? (uv.x - uv1.x) : (uv.y - uv1.y);
	float distance2 = isHorizontal ? (uv2.x - uv.x) : (uv2.y - uv.y);
	
	// In which direction is the side of the edge closer ?
	bool isDirection1 = distance1 < distance2;
	float distanceFinal = min(distance1, distance2);
	
	// Thickness of the edge.
	float edgeThickness = (distance1 + distance2);
	
	// Is the luma at center smaller than the local average ?
	bool isLumaCenterSmaller = lumaCenter < lumaLocalAverage;
	
	// If the luma at center is smaller than at its neighbour, the delta luma at each end should be positive (same variation).
	bool correctVariation1 = (lumaEnd1 < 0.0) != isLumaCenterSmaller;
	bool correctVariation2 = (lumaEnd2 < 0.0) != isLumaCenterSmaller;
	
	// Only keep the result in the direction of the closer side of the edge.
	bool correctVariation = isDirection1 ? correctVariation1 : correctVariation2;
	
	// UV offset: read in the direction of the closest side of the edge.
	float pixelOffset = -distanceFinal / edgeThickness + 0.5;
	
	// If the luma variation is incorrect, do not offset.
	float finalOffset = correctVariation ? pixelOffset : 0.0;
	
	// Sub-pixel shifting
	// Full weighted average of the luma over the 3x3 neighborhood.
	float lumaAverage = (1.0/12.0) * (2.0 * (lumaDownUp + lumaLeftRight) + lumaLeftCorners + lumaRightCorners);
	// Ratio of the delta between the global average and the center luma, over the luma range in the 3x3 neighborhood.
	float subPixelOffset1 = saturate(abs(lumaAverage - lumaCenter) / lumaRange);
	float subPixelOffset2 = (-2.0 * subPixelOffset1 + 3.0) * subPixelOffset1 * subPixelOffset1;
	// Compute a sub-pixel offset based on this delta.
	float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * FXAA_SUBPIXEL_QUALITY;
	
	// Pick the biggest of the two offsets.
	finalOffset = max(finalOffset, subPixelOffsetFinal);
	
	// Compute the final UV coordinates.
	vec2 finalUv = uv;
	if (isHorizontal) {
		finalUv.y += finalOffset * stepLength;
	} else {
		finalUv.x += finalOffset * stepLength;
	}
	
	// Read the color at the new UV coordinates, and use it.
	return textureLod(BUFFER_HDR_OPAQUE, finalUv, 0.0).rgb;
}
