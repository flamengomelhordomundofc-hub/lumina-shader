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

float waterHeight(vec2 p, float t) {
    float h1 = smoothNoise(p * 0.75 + vec2(t * 0.55, t * 0.30));
    float h2 = smoothNoise(p * 1.65 - vec2(t * 0.42, -t * 0.58));
    return h1 * 0.62 + h2 * 0.38;
}

vec3 getWaterNormal(vec2 p, float t) {
    float e = 0.08;
    float hC = waterHeight(p, t);
    float hX = waterHeight(p + vec2(e, 0.0), t);
    float hZ = waterHeight(p + vec2(0.0, e), t);
    return safeNormalize(vec3((hC - hX) * 1.65, 1.0, (hC - hZ) * 1.65));
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
        vec3 absP = vWorldPos + cameraPosition;
        vec3 wN = (abs(N.y) > 0.5) ? getWaterNormal(absP.xz, frameTimeCounter) : N;

        float cloudQ = 0.0;
#ifdef REALISTIC_CLOUDS
        cloudQ = 1.0;
#endif
        vec3 R = reflect(viewDir, wN);
        R.y = max(abs(R.y), 0.04);
        vec3 reflCol = computeSky(R, sunDir, frameTimeCounter, rainStrength, cloudQ) * (0.18 + 0.82 * skyLight);

        float cosT = max(dot(-viewDir, wN), 0.0);
        float fresnel = clamp(0.06 + 0.86 * pow(1.0 - cosT, 3.6), 0.0, 0.92);

        vec3 biomeTint = toLinear(vColor.rgb);
        vec3 waterTint = mix(vec3(0.05, 0.30, 0.38), biomeTint * vec3(0.18, 0.42, 0.48), 0.55);
        vec3 bodyCol = waterTint * (ambientCol * 1.1 * skyLight + directCol * 0.45 * skyLight + vec3(0.04));

        vec3 H = safeNormalize(lightDir - viewDir);
        float specSoft = pow(max(dot(wN, H), 0.0001), 36.0) * 0.25;
        float specSharp = pow(max(dot(wN, H), 0.0001), 160.0) * 2.4;
        vec3 specular = directCol * (specSoft + specSharp) * skyLight;

        vec3 torchCol = vec3(1.0, 0.55, 0.20) * pow(max(torchLight, 0.0001), 2.2) * 0.9;
        color = mix(bodyCol, reflCol, fresnel) + specular + bodyCol * torchCol;
        alpha = mix(0.48, 0.90, fresnel);
    } else
#endif
    {
        vec3 albedo = toLinear(tex.rgb);
        float diff = max(dot(N, lightDir), 0.0);
        vec3 torchCol = vec3(1.0, 0.55, 0.20) * pow(max(torchLight, 0.0001), 2.2) * 1.8;
        color = albedo * (ambientCol * skyLight + directCol * diff * skyLight + torchCol + vec3(0.04));

        vec3 R = reflect(viewDir, N);
        float fres = 0.06 + 0.40 * pow(1.0 - max(dot(-viewDir, N), 0.0), 3.0);
        color += computeSky(R, sunDir, frameTimeCounter, rainStrength, 0.0) * fres * 0.35 * skyLight;
    }

    float fogF = smoothstep(far * 0.52, far * 0.98, dist);
    vec3 fogDir = safeNormalize(vec3(viewDir.x, max(viewDir.y, 0.02), viewDir.z));
    color = mix(color, computeSky(fogDir, sunDir, frameTimeCounter, rainStrength, 0.0), fogF);

    color = toSRGB(softToneMap(color));
    gl_FragColor = vec4(color, alpha);
}
