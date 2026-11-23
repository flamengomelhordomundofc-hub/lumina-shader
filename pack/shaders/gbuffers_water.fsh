#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform sampler2D depthtex1;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;
varying float vIsWater;

vec3 getWaterNormal(vec2 pos, float t) {
    float w1 = sin(pos.x * 2.6 + t * 2.4) * cos(pos.y * 2.2 - t * 1.9);
    float w2 = sin((pos.x * 1.9 - pos.y * 2.7) + t * 3.1);
    float w3 = cos((pos.x * 4.4 + pos.y * 3.8) - t * 3.8);
    float w4 = sin((pos.x * 6.5 - pos.y * 5.2) + t * 4.2);
    float dx = (w1 * 0.42 + w2 * 0.32 + w3 * 0.18 + w4 * 0.12) * 0.19;
    float dz = (w1 * 0.32 - w2 * 0.42 + w3 * 0.18 - w4 * 0.12) * 0.19;
    return safeNormalize(vec3(dx, 1.0, dz));
}

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    if (tex.a < 0.01) discard;

    vec3 N = safeNormalize(vWorldNormal);
    vec3 viewWorldDir = safeNormalize(vWorldPos);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 zen, hor, lCol, aSky;
    getAtmosphere(sunDir.y, rainStrength, zen, hor, lCol, aSky);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float dist = length(vViewPos);

    vec3 color;
    float alpha = tex.a;

#ifdef REALISTIC_WATER
    if (vIsWater > 0.5) {
        vec3 absP = vWorldPos + cameraPosition;
        vec3 wN = (abs(N.y) > 0.5) ? getWaterNormal(absP.xz, frameTimeCounter) : N;

        vec2 screenUV = gl_FragCoord.xy / vec2(max(viewWidth, 1.0), max(viewHeight, 1.0));
        float bgDepth = linearizeDepth(texture2D(depthtex1, screenUV).r, near, far);
        float fgDepth = linearizeDepth(gl_FragCoord.z, near, far);
        float thickness = (bgDepth > fgDepth + 0.01) ? (bgDepth - fgDepth) : 2.8;
        float depthFade = 1.0 - exp(-thickness * 0.30);

        float cloudsOn = 0.0;
#ifdef REALISTIC_CLOUDS
        cloudsOn = 1.0;
#endif
        vec3 R = reflect(viewWorldDir, wN);
        R.y = max(abs(R.y), 0.02);
        vec3 skyRefl = computeSkyFull(R, sunDir, frameTimeCounter, rainStrength, cloudsOn, 0.0) * (0.18 + 0.82 * skyLight);

        float cosTheta = max(dot(-viewWorldDir, wN), 0.0);
        float fresnel = clamp(0.05 + 0.95 * pow(1.0 - cosTheta, 3.8), 0.0, 1.0);

        vec3 shallowCol = vec3(0.07, 0.52, 0.56);
        vec3 deepCol = vec3(0.012, 0.08, 0.20);
        vec3 waterTint = mix(shallowCol, deepCol, depthFade) * (0.45 + 0.55 * srgbToLinear(vColor.rgb));
        vec3 waterBody = waterTint * (aSky * 0.9 * skyLight + lCol * 0.55 * skyLight + vec3(0.04));

        vec3 H = safeNormalize(lightDir - viewWorldDir);
        float specWide = pow(max(dot(wN, H), 0.0001), 32.0) * 0.45;
        float specSharp = pow(max(dot(wN, H), 0.0001), 220.0) * 6.5;
        vec3 specular = lCol * (specWide + specSharp) * skyLight;

        vec3 torchCol = vec3(1.0, 0.52, 0.18) * pow(max(torchLight, 0.0001), 2.2) * 1.4;
        color = mix(waterBody, skyRefl, fresnel) + specular + waterBody * torchCol;

        float foamWave = sin(thickness * 15.0 - frameTimeCounter * 3.4 + absP.x * 2.2 + absP.z * 2.2) * 0.5 + 0.5;
        float foam = smoothstep(0.48, 0.02, thickness) * (0.45 + 0.55 * foamWave) * smoothstep(25.0, 4.0, dist);
        vec3 foamCol = (aSky * 0.6 + lCol * 0.7 + vec3(0.15)) * (0.35 + 0.65 * skyLight);
        color = mix(color, foamCol, foam * 0.68);

        alpha = clamp(max(mix(0.32, 0.88, depthFade), fresnel) + foam * 0.45, 0.30, 0.96);
    } else
#endif
    {
        vec3 albedo = srgbToLinear(tex.rgb);
        float diffuse = max(dot(N, lightDir), 0.0);
        vec3 torchCol = vec3(1.0, 0.52, 0.18) * pow(max(torchLight, 0.0001), 2.3) * 2.2;
        color = albedo * (aSky * 0.55 * skyLight + lCol * diffuse * skyLight + torchCol + vec3(0.05));

        vec3 R = reflect(viewWorldDir, N);
        float fresnel = 0.08 + 0.52 * pow(1.0 - max(dot(-viewWorldDir, N), 0.0), 3.0);
        color += computeSkyBase(R, sunDir, rainStrength) * fresnel * 0.45 * skyLight;
    }

    float fogF = smoothstep(far * 0.48, far * 0.98, dist);
    vec3 fogDir = safeNormalize(vec3(viewWorldDir.x, max(viewWorldDir.y, 0.02), viewWorldDir.z));
    color = mix(color, computeSkyBase(fogDir, sunDir, rainStrength), fogF);

    gl_FragColor = vec4(encodeHDR(color), alpha);
}
