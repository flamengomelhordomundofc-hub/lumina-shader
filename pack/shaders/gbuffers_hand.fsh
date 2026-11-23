#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform float rainStrength;
uniform float nightVision;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform vec3 fogColor;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    if (tex.a < 0.1) discard;

    vec3 albedo = toLinear(tex.rgb);
    vec3 N = safeNormalize(vWorldNormal);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 skyTop, skyHor, directCol, ambientCol;
    getLightingPalette(sunDir.y, rainStrength, skyTop, skyHor, directCol, ambientCol);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float heldVal = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    torchLight = max(torchLight, heldVal * 0.85);

    float diff = max(dot(N, lightDir), 0.0) * 0.72 + 0.28;
    vec3 torchCol = vec3(1.0, 0.56, 0.22) * pow(max(torchLight, 0.0001), 2.1) * 1.8;
    vec3 amb = toLinear(fogColor) * 0.12 + vec3(0.04) + vec3(0.35) * nightVision;

    vec3 color = albedo * (ambientCol * skyLight + directCol * diff * skyLight + torchCol + amb);
    color = toSRGB(softToneMap(color));
    gl_FragColor = vec4(color, tex.a);
}
