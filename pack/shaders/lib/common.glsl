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

vec3 softToneMap(vec3 x) {
    x = max(x, vec3(0.0));
    return x / (x * 0.72 + vec3(0.88));
}

vec2 distortShadow(vec2 p) {
    return p / mix(1.0, length(p), 0.78);
}

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.53);
    return fract(p.x * p.y);
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
    float v = smoothNoise(p) * 0.55;
    p = p * 2.08 + vec2(5.2, 1.3);
    v += smoothNoise(p) * 0.30;
    p = p * 2.12 + vec2(1.7, 9.2);
    v += smoothNoise(p) * 0.15;
    return v;
}

float cloudNoise2(vec2 p) {
    return smoothNoise(p) * 0.65 + smoothNoise(p * 2.15 + vec2(4.1, 2.7)) * 0.35;
}

void getLightingPalette(float sunH, float rain, out vec3 skyTop, out vec3 skyHor, out vec3 directCol, out vec3 ambientCol) {
    float dayF = smoothstep(-0.08, 0.22, sunH);
    float setF = smoothstep(-0.14, 0.04, sunH) * (1.0 - smoothstep(0.04, 0.34, sunH));

    vec3 dayTop = vec3(0.05, 0.22, 0.68);
    vec3 dayHor = vec3(0.30, 0.56, 0.86);
    vec3 setTop = vec3(0.08, 0.14, 0.36);
    vec3 setHor = vec3(0.95, 0.32, 0.09);
    vec3 nitTop = vec3(0.008, 0.015, 0.042);
    vec3 nitHor = vec3(0.018, 0.032, 0.068);

    skyTop = mix(nitTop, dayTop, dayF);
    skyTop = mix(skyTop, setTop, setF * 0.85);
    skyHor = mix(nitHor, dayHor, dayF);
    skyHor = mix(skyHor, setHor, setF * 0.90);

    vec3 rainTop = mix(vec3(0.012, 0.016, 0.024), vec3(0.14, 0.17, 0.21), dayF);
    vec3 rainHor = mix(vec3(0.022, 0.026, 0.035), vec3(0.24, 0.27, 0.31), dayF);
    skyTop = mix(skyTop, rainTop, rain * 0.85);
    skyHor = mix(skyHor, rainHor, rain * 0.85);

    vec3 sunWarm = mix(vec3(1.35, 0.48, 0.14), vec3(1.25, 1.12, 0.92), smoothstep(0.0, 0.30, sunH));
    vec3 moonCool = vec3(0.14, 0.20, 0.32);
    directCol = (sunH >= 0.0) ? sunWarm : moonCool;
    directCol *= smoothstep(0.0, 0.10, abs(sunH));
    directCol *= (1.0 - rain * 0.78);

    vec3 dayAmb = vec3(0.22, 0.27, 0.34);
    vec3 setAmb = vec3(0.24, 0.17, 0.20);
    vec3 nitAmb = vec3(0.035, 0.048, 0.080);
    ambientCol = mix(nitAmb, dayAmb, dayF);
    ambientCol = mix(ambientCol, setAmb, setF * 0.80);
    ambientCol = mix(ambientCol, vec3(0.18, 0.20, 0.23) * max(dayF, 0.22), rain * 0.75);
}

vec3 computeSky(vec3 dir, vec3 sunDir, float time, float rain, float cloudQuality) {
    vec3 skyTop, skyHor, directCol, ambCol;
    getLightingPalette(sunDir.y, rain, skyTop, skyHor, directCol, ambCol);

    float up = clamp(dir.y, 0.0, 1.0);
    vec3 sky = mix(skyHor, skyTop, pow(max(up, 0.0001), 0.55));

    float down = clamp(-dir.y, 0.0, 1.0);
    sky = mix(sky, skyHor * 0.55, smoothstep(0.0, 0.35, down));

    float sunDot = max(dot(dir, sunDir), 0.0);
    float sunVis = smoothstep(-0.10, 0.06, sunDir.y) * (1.0 - rain * 0.90);
    vec3 sunGlow = mix(vec3(1.15, 0.38, 0.08), vec3(0.95, 0.82, 0.58), smoothstep(0.0, 0.32, sunDir.y));
    sky += sunGlow * pow(max(sunDot, 0.0001), 9.0) * 0.28 * sunVis;
    sky += sunGlow * pow(max(sunDot, 0.0001), 96.0) * 0.85 * sunVis;
    sky += vec3(1.8, 1.55, 1.15) * smoothstep(0.9982, 0.9994, sunDot) * sunVis;

    float moonDot = max(dot(dir, -sunDir), 0.0);
    float moonVis = (1.0 - smoothstep(-0.10, 0.06, sunDir.y)) * (1.0 - rain * 0.90);
    sky += vec3(0.18, 0.28, 0.48) * pow(max(moonDot, 0.0001), 22.0) * 0.30 * moonVis;
    sky += vec3(0.75, 0.85, 1.05) * smoothstep(0.9986, 0.9995, moonDot) * moonVis;

    if (cloudQuality > 0.5 && dir.y > 0.03) {
        vec2 cUV = (dir.xz / (dir.y + 0.16)) * 1.4 + vec2(time * 0.012, time * 0.006);
        float d = (cloudQuality > 1.5) ? cloudNoise3(cUV) : cloudNoise2(cUV);
        float dSun = (cloudQuality > 1.5) ? cloudNoise2(cUV + sunDir.xz * 0.14) : d * 0.92;

        float cov = mix(0.49, 0.30, rain);
        float alpha = smoothstep(cov, cov + 0.24, d);

        float dayF = smoothstep(-0.08, 0.22, sunDir.y);
        float setF = smoothstep(-0.12, 0.04, sunDir.y) * (1.0 - smoothstep(0.04, 0.34, sunDir.y));
        float shade = clamp((d - dSun) * 2.2 + 0.62, 0.20, 1.0);

        vec3 cLit = mix(vec3(0.09, 0.13, 0.22), vec3(0.95, 0.94, 0.92), dayF);
        cLit = mix(cLit, vec3(1.15, 0.46, 0.18), setF * 0.90);
        cLit = mix(cLit, vec3(0.28, 0.30, 0.34) * max(dayF, 0.2), rain * 0.82);

        vec3 cDark = mix(vec3(0.02, 0.03, 0.06), vec3(0.32, 0.40, 0.52), dayF);
        cDark = mix(cDark, vec3(0.24, 0.15, 0.24), setF * 0.85);
        cDark = mix(cDark, vec3(0.11, 0.13, 0.16) * max(dayF, 0.2), rain * 0.82);

        vec3 cloudCol = mix(cDark, cLit, shade);
        cloudCol += sunGlow * pow(max(sunDot, 0.0001), 10.0) * 0.28 * sunVis * (1.0 - alpha * 0.4);

        float horFade = smoothstep(0.03, 0.24, dir.y);
        sky = mix(sky, cloudCol, alpha * horFade * 0.88);
    }

    return sky;
}

vec3 getWaveOffset(vec3 absPos, float time, float rain, float strength) {
    float speed = 2.0 + rain * 1.6;
    float amp = (0.045 + rain * 0.04) * strength;
    float ph = absPos.x * 0.9 + absPos.z * 0.75 + absPos.y * 0.5;
    return vec3(sin(time * speed + ph) * amp, 0.0, cos(time * speed * 0.85 + ph * 1.1) * amp * 0.8);
}
