#define ATMOSPHERE_SAMPLES 16


struct ScatteringParams {
    float sunRadius;
	float sunRadiance;

	float mieG;
	float mieHeight;

	float rayleighHeight;

	vec3 waveLambdaMie;
	vec3 waveLambdaOzone;
	vec3 waveLambdaRayleigh;

	float earthRadius;
	float earthAtmTopRadius;
	vec3 earthCenter;
};

vec2 ComputeRaySphereIntersection(const in vec3 position, const in vec3 dir, const in vec3 center, const in float radius) {
	vec3 origin = position - center;
	float B = dot(origin, dir);
	float C = dot(origin, origin) - radius * radius;
	float D = B * B - C;

	if (D < 0.0) return -vec2(1.0);

	D = sqrt(D);
	return vec2(-B - D, -B + D);
}

vec3 ComputeWaveLambdaRayleigh(const in vec3 lambda) {
	float n = 1.0003;
	float N = 2.545E25;
	float pn = 0.035;
	float n2 = n * n;
	float pi3 = PI * PI * PI;
	float rayleighConst = (8.0 * pi3 * pow(n2 - 1.0, 2.0)) / (3.0 * N) * ((6.0 + 3.0 * pn) / (6.0 - 7.0 * pn));
	return rayleighConst / (lambda * lambda * lambda * lambda);
}

float ComputePhaseMie(const in float theta, const in float g) {
	float g2 = g * g;
	return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * clamp(theta, 0.0, 1.0), 1.5) / (4.0 * PI);
}

float ComputePhaseRayleigh(const in float theta) {
	float theta2 = theta * theta;
	return (theta2 * 0.75 + 0.75) / (4.0 * PI);
}

float ChapmanApproximation(const in float X, const in float h, const in float cosZenith) {
	float c = sqrt(X + h);
	float c_exp_h = c * exp(-h);

	if (cosZenith >= 0.0)
		return c_exp_h / (c * cosZenith + 1.0);
	
	float x0 = sqrt(1.0 - cosZenith * cosZenith) * (X + h);
	float c0 = sqrt(x0);

	return 2.0 * c0 * exp(X - x0) - c_exp_h / (1.0 - c * cosZenith);
}

float GetOpticalDepthSchueler(const in float h, const in float H, const in float earthRadius, const in float cosZenith) {
	return H * ChapmanApproximation(earthRadius / H, h / H, cosZenith);
}

vec3 GetTransmittance(const in ScatteringParams setting, const in vec3 L, const in vec3 V) {
	float ch = GetOpticalDepthSchueler(L.y, setting.rayleighHeight, setting.earthRadius, V.y);
	return exp(-(setting.waveLambdaMie + setting.waveLambdaRayleigh) * ch);
}

vec2 ComputeOpticalDepth(const in ScatteringParams setting, const in vec3 samplePoint, const in vec3 V, const in vec3 L, const in float neg) {
	float rl = length(samplePoint);
	float h = rl - setting.earthRadius;
	vec3 r = samplePoint / rl;

	float cos_chi_sun = dot(r, L);
	float cos_chi_ray = dot(r, V * neg);

	float opticalDepthSun = GetOpticalDepthSchueler(h, setting.rayleighHeight, setting.earthRadius, cos_chi_sun);
	float opticalDepthCamera = GetOpticalDepthSchueler(h, setting.rayleighHeight, setting.earthRadius, cos_chi_ray) * neg;

	return vec2(opticalDepthSun, opticalDepthCamera);
}

void AerialPerspective(const in ScatteringParams setting, const in vec3 start, const in vec3 end, const in vec3 V, const in vec3 L, const in bool infinite, out vec3 transmittance, out vec3 insctrMie, out vec3 insctrRayleigh) {
	float inf_neg = infinite ? 1.0 : -1.0;

	vec3 sampleStep = (end - start) / float(ATMOSPHERE_SAMPLES);
	vec3 samplePoint = end - sampleStep;
	
	vec3 sampleLambda = setting.waveLambdaMie + setting.waveLambdaRayleigh + setting.waveLambdaOzone;

	float sampleLength = length(sampleStep);

	vec3 scattering = vec3(0.0);
	vec2 lastOpticalDepth = ComputeOpticalDepth(setting, end, V, L, inf_neg);

	//[unroll]
	for (int i = 1; i < ATMOSPHERE_SAMPLES; i++, samplePoint -= sampleStep) {
		vec2 opticalDepth = ComputeOpticalDepth(setting, samplePoint, V, L, inf_neg);

		vec3 segment_s = exp(-sampleLambda * (opticalDepth.x + lastOpticalDepth.x));
		vec3 segment_t = exp(-sampleLambda * (opticalDepth.y - lastOpticalDepth.y));
		
		transmittance *= segment_t;
		
		scattering = scattering * segment_t;
		scattering += exp(-(length(samplePoint) - setting.earthRadius) / setting.rayleighHeight) * segment_s;

		lastOpticalDepth = opticalDepth;
	}

	insctrMie = scattering * setting.waveLambdaMie * sampleLength;
	insctrRayleigh = scattering * setting.waveLambdaRayleigh * sampleLength;
}

float ComputeSkyboxChapman(const in ScatteringParams setting, in vec3 eye, const in vec3 V, const in vec3 L, out vec3 transmittance, out vec3 insctrMie, out vec3 insctrRayleigh) {
	bool neg = true;

	vec2 outerIntersections = ComputeRaySphereIntersection(eye, V, setting.earthCenter, setting.earthAtmTopRadius);
	
	if (outerIntersections.y < 0.0) {
		transmittance = vec3(0.0);
		insctrMie = vec3(0.0);
		insctrRayleigh = vec3(0.0);
		return 0.0;
	}
	
	vec2 innerIntersections = ComputeRaySphereIntersection(eye, V, setting.earthCenter, setting.earthRadius);
	
	if (innerIntersections.x > 0.0) {
		neg = false;
		outerIntersections.y = innerIntersections.x;
	}

	eye -= setting.earthCenter;

	vec3 start = eye + V * max(0.0, outerIntersections.x);
	vec3 end = eye + V * outerIntersections.y;

	AerialPerspective(setting, start, end, V, L, neg, transmittance, insctrMie, insctrRayleigh);

	// TODO: replace with step()
	bool intersectionTest = innerIntersections.x < 0.0 && innerIntersections.y < 0.0;
	return intersectionTest ? 1.0 : 0.0;
}

vec4 ComputeSkyInscattering(const in ScatteringParams setting, const in vec3 eye, const in vec3 V, const in vec3 L) {
	vec3 insctrMie = vec3(0.0);
	vec3 insctrRayleigh = vec3(0.0);
	vec3 insctrOpticalLength = vec3(1.0);
	float intersectionTest = ComputeSkyboxChapman(setting, eye, V, L, insctrOpticalLength, insctrMie, insctrRayleigh);

	float phaseTheta = dot(V, L);
	float phaseMie = ComputePhaseMie(phaseTheta, setting.mieG);
	float phaseRayleigh = ComputePhaseRayleigh(phaseTheta);
	float phaseNight = 1.0 - clamp(insctrOpticalLength.x * EPSILON, 0.0, 1.0);

	vec3 insctrTotalMie = insctrMie * phaseMie;
	vec3 insctrTotalRayleigh = insctrRayleigh * phaseRayleigh;

	vec3 sky = (insctrTotalMie + insctrTotalRayleigh) * setting.sunRadiance;

	float angle = clamp((1.0 - phaseTheta) * setting.sunRadius, 0.0, 1.0);
	float cosAngle = max(cos(angle * PI * 0.5), 0.0);
	float edge = (angle >= 0.9) ? smoothstep(0.9, 1.0, angle) : 0.0;
                         
	vec3 limbDarkening = GetTransmittance(setting, -L, V);
	limbDarkening *= pow(vec3(cosAngle), vec3(0.420, 0.503, 0.652)) * mix(vec3(1.0), vec3(1.2, 0.9, 0.5), edge) * intersectionTest;

	sky += limbDarkening;

	return vec4(sky, phaseNight * intersectionTest);
}

// float noise(const in vec2 uv) {
// 	return frac(dot(sin(uv.xyx * uv.xyy * 1024.0f), vec3(341896.483f, 891618.637f, 602649.7031f)));
// }
