// https://www.shadertoy.com/view/XtBGDG
// https://www.shadertoy.com/view/3dVXDc

#define UI0 1597334673U
#define UI1 3812015801U
//#define UI2 uvec2(UI0, UI1)
#define UI3 uvec3(UI0, UI1, 2798796415U)
#define UIF (1.0 / float(0xffffffffU))

#define PHYSICS_SNOW_NOISE 0.06
#define PHYSICS_SNOW_RESOLUTION 64 // [16 32 64 128]

const vec3 PHYSICS_SNOW_COLOR = vec3(0.373, 0.485, 0.510);


vec3 hash33(const in vec3 p) {
	uvec3 q = uvec3(ivec3(p)) * UI3;
	q = (q.x ^ q.y ^ q.z) * UI3;
	return -1.0 + 2.0 * vec3(q) * UIF;
}

float noise3D(const in vec3 p) {
	const vec3 x = vec3(12.9898, 78.233, 128.852);
	return fract(sin(dot(p, x)) * 43758.5453) * 2.0 - 1.0;
}

float simplex3D(const in vec3 p) {
	const float f3 = 1.0/3.0;
	float s = (p.x+p.y+p.z)*f3;
	int i = int(floor(p.x+s));
	int j = int(floor(p.y+s));
	int k = int(floor(p.z+s));
	
	const float g3 = 1.0/6.0;
	float t = float((i+j+k))*g3;
	float x0 = float(i)-t;
	float y0 = float(j)-t;
	float z0 = float(k)-t;
	x0 = p.x-x0;
	y0 = p.y-y0;
	z0 = p.z-z0;
	
	int i1,j1,k1;
	int i2,j2,k2;
	
	if(x0>=y0) {
		if (y0 >= z0) { i1=1; j1=0; k1=0; i2=1; j2=1; k2=0; } // X Y Z order
		else if (x0 >= z0) { i1=1; j1=0; k1=0; i2=1; j2=0; k2=1; } // X Z Y order
		else { i1=0; j1=0; k1=1; i2=1; j2=0; k2=1; }  // Z X Z order
	}
	else {
		if (y0 < z0) { i1=0; j1=0; k1=1; i2=0; j2=1; k2=1; } // Z Y X order
		else if (x0 < z0) { i1=0; j1=1; k1=0; i2=0; j2=1; k2=1; } // Y Z X order
		else { i1=0; j1=1; k1=0; i2=1; j2=1; k2=0; } // Y X Z order
	}
	
	float x1 = x0 - float(i1) + g3; 
	float y1 = y0 - float(j1) + g3;
	float z1 = z0 - float(k1) + g3;
	float x2 = x0 - float(i2) + 2.0*g3; 
	float y2 = y0 - float(j2) + 2.0*g3;
	float z2 = z0 - float(k2) + 2.0*g3;
	float x3 = x0 - 1.0 + 3.0*g3; 
	float y3 = y0 - 1.0 + 3.0*g3;
	float z3 = z0 - 1.0 + 3.0*g3;	
				 
	vec3 ijk0 = vec3(i, j, k);
	vec3 ijk1 = vec3(i+i1, j+j1, k+k1);	
	vec3 ijk2 = vec3(i+i2, j+j2, k+k2);
	vec3 ijk3 = vec3(i+1, j+1, k+1);	
            
	vec3 gr0 = normalize(vec3(noise3D(ijk0), noise3D(ijk0*2.01), noise3D(ijk0*2.02)));
	vec3 gr1 = normalize(vec3(noise3D(ijk1), noise3D(ijk1*2.01), noise3D(ijk1*2.02)));
	vec3 gr2 = normalize(vec3(noise3D(ijk2), noise3D(ijk2*2.01), noise3D(ijk2*2.02)));
	vec3 gr3 = normalize(vec3(noise3D(ijk3), noise3D(ijk3*2.01), noise3D(ijk3*2.02)));
	
	float n0 = 0.0;
	float n1 = 0.0;
	float n2 = 0.0;
	float n3 = 0.0;

	float t0 = 0.5 - x0*x0 - y0*y0 - z0*z0;
	if (t0 >= 0.0) {
		t0 *= t0;
		n0 = t0 * t0 * dot(gr0, vec3(x0, y0, z0));
	}

	float t1 = 0.5 - x1*x1 - y1*y1 - z1*z1;
	if (t1 >= 0.0) {
		t1*=t1;
		n1 = t1 * t1 * dot(gr1, vec3(x1, y1, z1));
	}

	float t2 = 0.5 - x2*x2 - y2*y2 - z2*z2;
	if (t2 >= 0.0) {
		t2 *= t2;
		n2 = t2 * t2 * dot(gr2, vec3(x2, y2, z2));
	}

	float t3 = 0.5 - x3*x3 - y3*y3 - z3*z3;
	if (t3 >= 0.0) {
		t3 *= t3;
		n3 = t3 * t3 * dot(gr3, vec3(x3, y3, z3));
	}

	return 96.0*(n0+n1+n2+n3);
}

float fbm(in vec3 p) {
	float f;
    f  = 0.50000*simplex3D(p); p = p*2.01;
    f += 0.25000*simplex3D(p); p = p*2.02; //from iq
    f += 0.12500*simplex3D(p); p = p*2.03;
    f += 0.06250*simplex3D(p); p = p*2.04;
    f += 0.03125*simplex3D(p);
	return f;
}

vec3 GetPhysicsSnowNormal(const in vec3 worldPos, const in vec3 geoNormal, const in float viewDist) {
	vec3 randomNormal, finalNormal;
	float weight;

	randomNormal = hash33((worldPos - 0.5) * 0.5 * 16.0);
	randomNormal *= sign(dot(randomNormal, geoNormal));
	weight = PHYSICS_SNOW_NOISE * saturate(1.0 - viewDist / 120.0);
	finalNormal = mix(geoNormal, randomNormal, weight);

	#if PHYSICS_SNOW_RESOLUTION >= 32
		randomNormal = hash33((worldPos - 0.5) * 0.5 * 32.0);
		randomNormal *= sign(dot(randomNormal, geoNormal));
		weight = PHYSICS_SNOW_NOISE * saturate(1.0 - viewDist / 60.0);
		finalNormal = mix(finalNormal, randomNormal, weight);
	#endif

	#if PHYSICS_SNOW_RESOLUTION >= 64
		randomNormal = hash33((worldPos - 0.5) * 0.5 * 64.0);
		randomNormal *= sign(dot(randomNormal, geoNormal));
		weight = PHYSICS_SNOW_NOISE * saturate(1.0 - viewDist / 30.0);
		finalNormal = mix(finalNormal, randomNormal, weight);
	#endif

	#if PHYSICS_SNOW_RESOLUTION >= 128
		randomNormal = hash33((worldPos - 0.5) * 0.5 * 128.0);
		randomNormal *= sign(dot(randomNormal, geoNormal));
		weight = PHYSICS_SNOW_NOISE * saturate(1.0 - viewDist / 15.0);
		finalNormal = mix(finalNormal, randomNormal, weight);
	#endif

	return normalize(finalNormal);
}

float GetPhysicsSnowScattering(const in vec3 worldPos) {
	float v = 1.0 - fbm(worldPos * 0.9);
	return saturate(0.32 + 0.16 * v);
}

float GetPhysicsSnowSmooth(const in vec3 worldPos) {
	float v = 1.0 - fbm(worldPos * 0.6);
	return saturate(0.2 + 0.3 * v);
}
