#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float far;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;
varying float vIsWater;

float waterWave(vec2 p, float t) {
    vec2 p1 = p * 0.85 + vec2(t * 0.65, t * 0.35);
    float w1 = smoothNoise(p1) * 0.50;
    vec2 p2 = vec2(p.x * 1.45 - p.y * 1.10, p.x * 1.10 + p.y * 1.45) + vec2(-t * 0.85, t * 0.55);
    float w2 = smoothNoise(p2) * 0.32;
    vec2 p3 = p * 3.30 + vec2(t * 1.10, -t * 0.90);
    float w3 = smoothNoise(p3) * 0.18;
    return w1 + w2 + w3;
}

vec3 getWaterNormal(vec2 p, float t, out float hOut) {
    float e = 0.12;
    float hC = waterWave(p, t);
    float hX = waterWave(p + vec2(e, 0.0), t);
    float hZ = waterWave(p + vec2(0.0, e), t);
    hOut = hC;
    vec2 grad = vec2(hC - hX, hC - hZ) / e;
    return safeNormalize(vec3(grad.x * 0.30, 1.0, grad.y * 0.30));
}

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    if (tex.a < 0.01) discard;

    vec3 N = safeNormalize(vWorldNormal);
    vec3 viewDir = safeNormalize(vWorldPos);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 skyTop, skyHor, directCol, ambientCol;
    getLightingPalette(sunDir.y, rainStrength, skyTop, skyHor, directCol, ambientCol);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float dist = length(vViewPos);

    vec3 color;
    float alpha = tex.a;

#ifdef REALISTIC_WATER
    if (vIsWater > 0.5) {
        vec2 wp = mod(vWorldPos.xz + cameraPosition.xz, 128.0);
        float hWave = 0.5;
        vec3 wN = (abs(N.y) > 0.5) ? getWaterNormal(wp, frameTimeCounter, hWave) : N;

        float cloudQ = 0.0;
#ifdef REALISTIC_CLOUDS
        cloudQ = 1.0;
#endif
        vec3 R = reflect(viewDir, wN);
        R.y = max(abs(R.y), 0.04);
        vec3 reflCol = computeSky(R, sunDir, frameTimeCounter, rainStrength, cloudQ) * (0.20 + 0.80 * skyLight);

        float cosT = max(dot(-viewDir, wN), 0.0);
        float fresnel = clamp(0.08 + 0.84 * pow(1.0 - cosT, 3.2), 0.0, 0.92);

        vec3 biomeTint = toLinear(vColor.rgb);
        vec3 crystalBlue = vec3(0.05, 0.42, 0.54);
        vec3 waterTint = mix(crystalBlue, biomeTint * vec3(0.18, 0.55, 0.65), 0.45);
        float crest = smoothstep(0.55, 0.85, hWave);
        vec3 bodyCol = waterTint * (ambientCol * 1.15 * skyLight + directCol * (0.48 + 0.25 * crest) * skyLight + vec3(0.05));

        vec3 H = safeNormalize(lightDir - viewDir);
        float specSoft = pow(max(dot(wN, H), 0.0001), 32.0) * 0.35;
        float specSharp = pow(max(dot(wN, H), 0.0001), 160.0) * 3.4;
        vec3 specular = directCol * (specSoft + specSharp) * skyLight;

        vec3 torchCol = vec3(1.0, 0.56, 0.20) * pow(max(torchLight, 0.0001), 2.1) * 1.1;
        color = mix(bodyCol, reflCol, fresnel) + specular + bodyCol * torchCol;
        alpha = mix(0.36, 0.88, fresnel);
    } else
#endif
    {
        vec3 albedo = toLinear(tex.rgb);
        float diff = max(dot(N, lightDir), 0.0);
        vec3 torchCol = vec3(1.0, 0.54, 0.18) * pow(max(torchLight, 0.0001), 2.2) * 1.9;
        color = albedo * (ambientCol * skyLight + directCol * diff * skyLight + torchCol + vec3(0.04));

        vec3 R = reflect(viewDir, N);
        float fres = 0.06 + 0.42 * pow(1.0 - max(dot(-viewDir, N), 0.0), 3.0);
        color += computeSky(R, sunDir, frameTimeCounter, rainStrength, 0.0) * fres * 0.35 * skyLight;
    }

    float fogF = smoothstep(far * 0.50, far * 0.98, dist);
    vec3 fogDir = safeNormalize(vec3(viewDir.x, max(viewDir.y, 0.02), viewDir.z));
    color = mix(color, computeSky(fogDir, sunDir, frameTimeCounter, rainStrength, 0.0), fogF);

    color = toSRGB(filmicToneMap(color));
    gl_FragColor = vec4(color, alpha);
}
