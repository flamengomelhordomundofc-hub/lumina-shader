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

    vec3 albedo = srgbToLinear(tex.rgb);
    vec3 N = safeNormalize(vWorldNormal);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 zen, hor, lCol, aSky;
    getAtmosphere(sunDir.y, rainStrength, zen, hor, lCol, aSky);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float heldVal = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    torchLight = max(torchLight, heldVal * 0.9);

    float diff = max(dot(N, lightDir), 0.0) * 0.78 + 0.22;
    vec3 torchCol = vec3(1.0, 0.54, 0.18) * pow(max(torchLight, 0.0001), 2.1) * 2.2;
    vec3 amb = srgbToLinear(fogColor) * 0.15 + vec3(0.04) + vec3(0.38) * nightVision;

    vec3 color = albedo * (aSky * 0.62 * skyLight + lCol * diff * skyLight + torchCol + amb);
    gl_FragColor = vec4(encodeHDR(color), tex.a);
}
