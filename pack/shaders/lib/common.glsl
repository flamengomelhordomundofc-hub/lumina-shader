vec3 safeNormalize(vec3 v) {
    float l2 = dot(v, v);
    return (l2 > 0.000001) ? v * inversesqrt(l2) : vec3(0.0, 1.0, 0.0);
}

vec3 srgbToLinear(vec3 c) {
    return pow(max(c, vec3(0.0001)), vec3(2.2));
}

vec3 linearToSRGB(vec3 c) {
    return pow(max(c, vec3(0.0001)), vec3(0.454545));
}

vec3 encodeHDR(vec3 x) {
    x = max(x, vec3(0.0));
    vec3 c = x / (x + vec3(1.8));
    return sqrt(max(c, vec3(0.0)));
}

vec3 decodeHDR(vec3 y) {
    vec3 c = clamp(y * y, vec3(0.0), vec3(0.955));
    return (c * 1.8) / (vec3(1.0) - c);
}

vec3 acesToneMap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n * f) / max(f + n - (d * 2.0 - 1.0) * (f - n), 0.0001);
}

vec2 distortShadow(vec2 p) {
    float dist = length(p);
    return p / mix(1.0, dist, 0.80);
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cloudFBM(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; i++) {
        v += amp * valueNoise(p);
        p = rot * p * 2.05 + vec2(1.7, 9.2);
        amp *= 0.5;
    }
    return v;
}

void getAtmosphere(float sunH, float rain, out vec3 zenith, out vec3 horizon, out vec3 lightCol, out vec3 ambSky) {
    float dayF = smoothstep(-0.08, 0.22, sunH);
    float sunsetF = smoothstep(-0.15, 0.04, sunH) * (1.0 - smoothstep(0.05, 0.36, sunH));

    vec3 dayZen = vec3(0.05, 0.24, 0.85);
    vec3 dayHor = vec3(0.46, 0.76, 1.12);
    vec3 setZen = vec3(0.08, 0.12, 0.42);
    vec3 setHor = vec3(1.65, 0.44, 0.10);
    vec3 nitZen = vec3(0.006, 0.014, 0.045);
    vec3 nitHor = vec3(0.020, 0.038, 0.088);

    zenith = mix(nitZen, dayZen, dayF);
    zenith = mix(zenith, setZen, sunsetF * 0.88);

    horizon = mix(nitHor, dayHor, dayF);
    horizon = mix(horizon, setHor, sunsetF * 0.95);

    vec3 rainZen = mix(vec3(0.012, 0.018, 0.030), vec3(0.16, 0.20, 0.26), dayF);
    vec3 rainHor = mix(vec3(0.025, 0.032, 0.046), vec3(0.32, 0.36, 0.42), dayF);
    zenith = mix(zenith, rainZen, rain * 0.86);
    horizon = mix(horizon, rainHor, rain * 0.86);

    vec3 sunCol = mix(vec3(2.35, 0.72, 0.18), vec3(2.15, 1.92, 1.58), smoothstep(0.0, 0.32, sunH));
    vec3 moonCol = vec3(0.24, 0.36, 0.64);
    lightCol = (sunH >= 0.0) ? sunCol : moonCol;
    lightCol *= smoothstep(0.0, 0.10, abs(sunH));
    lightCol *= (1.0 - rain * 0.76);

    ambSky = mix(zenith, horizon, 0.45);
}

vec3 computeSkyBase(vec3 dir, vec3 sunDir, float rain) {
    vec3 zen, hor, lCol, aSky;
    getAtmosphere(sunDir.y, rain, zen, hor, lCol, aSky);

    float up = clamp(dir.y, 0.0, 1.0);
    vec3 sky = mix(hor, zen, pow(max(up, 0.0001), 0.52));

    float below = clamp(-dir.y, 0.0, 1.0);
    sky = mix(sky, hor * 0.45, smoothstep(0.0, 0.38, below));

    float sunDot = max(dot(dir, sunDir), 0.0);
    float sunVis = smoothstep(-0.12, 0.06, sunDir.y) * (1.0 - rain * 0.90);
    vec3 glowCol = mix(vec3(1.8, 0.48, 0.10), vec3(1.4, 1.18, 0.85), smoothstep(0.0, 0.34, sunDir.y));
    sky += glowCol * pow(max(sunDot, 0.0001), 7.0) * 0.52 * sunVis;
    sky += glowCol * pow(max(sunDot, 0.0001), 85.0) * 2.4 * sunVis;
    sky += vec3(6.5, 5.6, 4.2) * smoothstep(0.9985, 0.9996, sunDot) * sunVis;

    float moonDot = max(dot(dir, -sunDir), 0.0);
    float moonVis = (1.0 - smoothstep(-0.12, 0.05, sunDir.y)) * (1.0 - rain * 0.90);
    sky += vec3(0.26, 0.42, 0.78) * pow(max(moonDot, 0.0001), 18.0) * 0.48 * moonVis;
    sky += vec3(1.8, 2.1, 2.6) * smoothstep(0.9988, 0.9996, moonDot) * moonVis;

    return sky;
}

vec3 computeSkyFull(vec3 dir, vec3 sunDir, float time, float rain, float allowClouds, float allowAurora) {
    vec3 sky = computeSkyBase(dir, sunDir, rain);

    float nightVis = (1.0 - smoothstep(-0.12, 0.06, sunDir.y)) * (1.0 - rain * 0.95);
    if (allowAurora > 0.5 && nightVis > 0.02 && dir.y > 0.08) {
        vec2 aUV = dir.xz / (dir.y + 0.25);
        float wave1 = sin(aUV.x * 2.2 + time * 0.28 + sin(aUV.y * 1.8 - time * 0.18));
        float wave2 = sin(aUV.x * 3.8 - time * 0.22 + aUV.y * 2.4);
        float band = exp(-abs(wave1 * 0.65 + wave2 * 0.35) * 4.5);
        float detail = 0.5 + 0.5 * valueNoise(aUV * 3.0 + vec2(0.0, time * 0.12));
        float mask = smoothstep(0.08, 0.38, dir.y) * smoothstep(0.92, 0.35, dir.y);
        vec3 aCol = mix(vec3(0.08, 0.95, 0.58), vec3(0.55, 0.16, 0.95), smoothstep(0.22, 0.68, dir.y));
        sky += aCol * band * detail * mask * nightVis * 0.42;
    }

    if (allowClouds > 0.5 && dir.y > 0.02) {
        vec3 zen, hor, lCol, aSky;
        getAtmosphere(sunDir.y, rain, zen, hor, lCol, aSky);

        vec2 cUV = (dir.xz / (dir.y + 0.15)) * 1.35 + vec2(time * 0.014, time * 0.007);
        float d1 = cloudFBM(cUV);
        float dSun = cloudFBM(cUV + sunDir.xz * 0.14);

        float cov = mix(0.47, 0.26, rain);
        float alpha = smoothstep(cov, cov + 0.25, d1);

        float lightTerm = clamp((d1 - dSun) * 2.4 + 0.55, 0.15, 1.0);
        float silver = pow(max(dot(dir, sunDir), 0.0001), 10.0) * (1.0 - alpha * 0.4);
        float dayF = smoothstep(-0.08, 0.22, sunDir.y);
        float sunsetF = smoothstep(-0.14, 0.04, sunDir.y) * (1.0 - smoothstep(0.05, 0.35, sunDir.y));

        vec3 cBright = mix(vec3(0.16, 0.24, 0.42), vec3(1.95, 1.88, 1.78), dayF);
        cBright = mix(cBright, vec3(2.4, 0.85, 0.32), sunsetF * 0.92);
        cBright = mix(cBright, vec3(0.42, 0.46, 0.52) * max(dayF, 0.18), rain * 0.85);

        vec3 cDark = mix(vec3(0.02, 0.035, 0.075), vec3(0.32, 0.46, 0.68), dayF);
        cDark = mix(cDark, vec3(0.34, 0.20, 0.32), sunsetF * 0.85);
        cDark = mix(cDark, vec3(0.10, 0.12, 0.16) * max(dayF, 0.2), rain * 0.85);

        vec3 cloudCol = mix(cDark, cBright, lightTerm);
        cloudCol += lCol * silver * 0.65 * (1.0 - rain * 0.8);

        float horFade = smoothstep(0.02, 0.22, dir.y);
        sky = mix(sky, cloudCol, alpha * horFade * 0.92);
    }

    return sky;
}

vec3 getWaveOffset(vec3 absPos, float time, float rain, float strength) {
    float speed = 2.2 + rain * 2.0;
    float amp = (0.055 + rain * 0.05) * strength;
    float phase = absPos.x * 0.9 + absPos.z * 0.75 + absPos.y * 0.5;
    float wx = sin(time * speed + phase) * amp;
    float wz = cos(time * speed * 0.85 + phase * 1.15) * amp * 0.85;
    return vec3(wx, 0.0, wz);
}
