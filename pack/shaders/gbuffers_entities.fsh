#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec4 entityColor;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float far;
uniform float nightVision;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform vec3 fogColor;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    if (tex.a < 0.1) discard;
    tex.rgb = mix(tex.rgb, entityColor.rgb, entityColor.a);

    vec3 albedo = toLinear(tex.rgb);
    vec3 N = safeNormalize(vWorldNormal);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 skyTop, skyHor, directCol, ambientCol;
    getLightingPalette(sunDir.y, rainStrength, skyTop, skyHor, directCol, ambientCol);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float dist = length(vViewPos);

    float heldVal = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    torchLight = max(torchLight, max(0.0, heldVal - dist / 14.0));

    float diff = max(dot(N, lightDir), 0.0) * 0.80 + 0.20;
    vec3 torchCol = vec3(1.0, 0.55, 0.20) * pow(max(torchLight, 0.0001), 2.2) * 1.9;
    vec3 amb = toLinear(fogColor) * 0.12 + vec3(0.025) + vec3(0.35) * nightVision;

    vec3 color = albedo * (ambientCol * skyLight + directCol * diff * skyLight + torchCol + amb);

    float fogF = smoothstep(far * 0.52, far * 0.98, dist);
    vec3 viewDir = safeNormalize(vWorldPos);
    vec3 fogDir = safeNormalize(vec3(viewDir.x, max(viewDir.y, 0.02), viewDir.z));
    color = mix(color, computeSky(fogDir, sunDir, frameTimeCounter, rainStrength, 0.0), fogF);

    color = toSRGB(softToneMap(color));
    gl_FragColor = vec4(color, tex.a);
}
