vec3 safeNormalize(vec3 v) {
    float l2 = dot(v, v);
    return (l2 > 0.000001) ? v * inversesqrt(l2) : vec3(0.0, 1.0, 0.0);
}

vec3 toLinear(vec3 c) {
    return pow(max(c, vec3(0.0001)), vec3(2.2));
}

vec3 toSRGB(vec3 c) {
    return pow(max(c, vec3(0.0001)), vec3(0.454545));
}

vec3 filmicToneMap(vec3 x) {
    x = max(x, vec3(0.0));
    return (x * (2.2 * x + 0.08)) / (x * (2.1 * x + 0.72) + 0.12);
}

vec2 distortShadow(vec2 p) {
    return p / mix(1.0, length(p), 0.78);
}

float hash21(vec2 p) {
    p = mod(p, 256.0);
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float smoothNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cloudNoise3(vec2 p) {
    float v = smoothNoise(p) * 0.54;
    p = p * 2.07 + vec2(4.3, 1.9);
    v += smoothNoise(p) * 0.30;
    p = p * 2.11 + vec2(2.1, 7.4);
    v += smoothNoise(p) * 0.16;
    return v;
}

float cloudNoise2(vec2 p) {
    return smoothNoise(p) * 0.64 + smoothNoise(p * 2.12 + vec2(3.7, 2.1)) * 0.36;
}

void getLightingPalette(float sunH, float rain, out vec3 skyTop, out vec3 skyHor, out vec3 directCol, out vec3 ambientCol) {
    float dayF = smoothstep(-0.08, 0.22, sunH);
    float setF = smoothstep(-0.14, 0.04, sunH) * (1.0 - smoothstep(0.04, 0.34, sunH));

    vec3 dayTop = vec3(0.06, 0.26, 0.78);
    vec3 dayHor = vec3(0.36, 0.66, 0.96);
    vec3 setTop = vec3(0.08, 0.14, 0.38);
    vec3 setHor = vec3(1.12, 0.38, 0.11);
    vec3 nitTop = vec3(0.008, 0.015, 0.042);
    vec3 nitHor = vec3(0.020, 0.036, 0.078);

    skyTop = mix(nitTop, dayTop, dayF);
    skyTop = mix(skyTop, setTop, setF * 0.85);
    skyHor = mix(nitHor, dayHor, dayF);
    skyHor = mix(skyHor, setHor, setF * 0.92);

    vec3 rainTop = mix(vec3(0.012, 0.016, 0.025), vec3(0.15, 0.18, 0.23), dayF);
    vec3 rainHor = mix(vec3(0.022, 0.028, 0.038), vec3(0.26, 0.30, 0.35), dayF);
    skyTop = mix(skyTop, rainTop, rain * 0.85);
    skyHor = mix(skyHor, rainHor, rain * 0.85);

    vec3 sunWarm = mix(vec3(1.55, 0.56, 0.16), vec3(1.38, 1.24, 1.02), smoothstep(0.0, 0.30, sunH));
    vec3 moonCool = vec3(0.16, 0.24, 0.40);
    directCol = (sunH >= 0.0) ? sunWarm : moonCool;
    directCol *= smoothstep(0.0, 0.10, abs(sunH));
    directCol *= (1.0 - rain * 0.78);

    vec3 dayAmb = vec3(0.35, 0.41, 0.48);
    vec3 setAmb = vec3(0.32, 0.22, 0.24);
    vec3 nitAmb = vec3(0.045, 0.062, 0.102);
    ambientCol = mix(nitAmb, dayAmb, dayF);
    ambientCol = mix(ambientCol, setAmb, setF * 0.82);
    ambientCol = mix(ambientCol, vec3(0.24, 0.26, 0.30) * max(dayF, 0.22), rain * 0.75);
}

vec3 computeSky(vec3 dir, vec3 sunDir, float time, float rain, float cloudQuality) {
    vec3 skyTop, skyHor, directCol, ambCol;
    getLightingPalette(sunDir.y, rain, skyTop, skyHor, directCol, ambCol);

    float up = clamp(dir.y, 0.0, 1.0);
    vec3 sky = mix(skyHor, skyTop, pow(max(up, 0.0001), 0.52));

    float down = clamp(-dir.y, 0.0, 1.0);
    sky = mix(sky, skyHor * 0.55, smoothstep(0.0, 0.36, down));

    float sunDot = max(dot(dir, sunDir), 0.0);
    float sunVis = smoothstep(-0.10, 0.06, sunDir.y) * (1.0 - rain * 0.90);
    vec3 sunGlow = mix(vec3(1.25, 0.42, 0.10), vec3(1.05, 0.90, 0.65), smoothstep(0.0, 0.32, sunDir.y));
    sky += sunGlow * pow(max(sunDot, 0.0001), 8.0) * 0.30 * sunVis;
    sky += sunGlow * pow(max(sunDot, 0.0001), 90.0) * 0.95 * sunVis;
    sky += vec3(2.4, 2.0, 1.4) * smoothstep(0.9980, 0.9994, sunDot) * sunVis;

    float moonDot = max(dot(dir, -sunDir), 0.0);
    float moonVis = (1.0 - smoothstep(-0.10, 0.06, sunDir.y)) * (1.0 - rain * 0.90);
    sky += vec3(0.20, 0.32, 0.56) * pow(max(moonDot, 0.0001), 20.0) * 0.32 * moonVis;
    sky += vec3(0.95, 1.05, 1.25) * smoothstep(0.9986, 0.9995, moonDot) * moonVis;

    if (cloudQuality > 0.5 && dir.y > 0.03) {
        vec2 cUV = (dir.xz / (dir.y + 0.16)) * 1.45 + vec2(time * 0.014, time * 0.007);
        float d = (cloudQuality > 1.5) ? cloudNoise3(cUV) : cloudNoise2(cUV);
        float dSun = (cloudQuality > 1.5) ? cloudNoise2(cUV + sunDir.xz * 0.15) : d * 0.92;

        float cov = mix(0.47, 0.28, rain);
        float alpha = smoothstep(cov, cov + 0.23, d);

        float dayF = smoothstep(-0.08, 0.22, sunDir.y);
        float setF = smoothstep(-0.12, 0.04, sunDir.y) * (1.0 - smoothstep(0.04, 0.34, sunDir.y));
        float shade = clamp((d - dSun) * 2.4 + 0.62, 0.18, 1.0);

        vec3 cLit = mix(vec3(0.10, 0.15, 0.26), vec3(1.12, 1.10, 1.06), dayF);
        cLit = mix(cLit, vec3(1.38, 0.54, 0.20), setF * 0.92);
        cLit = mix(cLit, vec3(0.30, 0.33, 0.38) * max(dayF, 0.22), rain * 0.84);

        vec3 cDark = mix(vec3(0.02, 0.03, 0.06), vec3(0.36, 0.45, 0.60), dayF);
        cDark = mix(cDark, vec3(0.26, 0.16, 0.26), setF * 0.86);
        cDark = mix(cDark, vec3(0.12, 0.14, 0.18) * max(dayF, 0.22), rain * 0.84);

        vec3 cloudCol = mix(cDark, cLit, shade);
        cloudCol += sunGlow * pow(max(sunDot, 0.0001), 10.0) * 0.38 * sunVis * (1.0 - alpha * 0.4);

        float horFade = smoothstep(0.03, 0.24, dir.y);
        sky = mix(sky, cloudCol, alpha * horFade * 0.90);
    }

    return sky;
}

vec3 getWaveOffset(vec3 absPos, float time, float rain, float strength) {
    vec3 p = mod(absPos, 62.8318);
    float speed = 2.1 + rain * 1.7;
    float amp = (0.045 + rain * 0.04) * strength;
    float ph = p.x * 0.9 + p.z * 0.75 + p.y * 0.5;
    return vec3(sin(time * speed + ph) * amp, 0.0, cos(time * speed * 0.85 + ph * 1.1) * amp * 0.8);
}
