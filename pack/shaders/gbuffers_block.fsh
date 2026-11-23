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

    vec3 albedo = srgbToLinear(tex.rgb);
    vec3 N = safeNormalize(vWorldNormal);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 zen, hor, lCol, aSky;
    getAtmosphere(sunDir.y, rainStrength, zen, hor, lCol, aSky);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float dist = length(vViewPos);

    float heldVal = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    torchLight = max(torchLight, max(0.0, heldVal - dist / 15.0));

    float diff = max(dot(N, lightDir), 0.0) * 0.85 + 0.15;
    vec3 torchCol = vec3(1.0, 0.52, 0.16) * pow(max(torchLight, 0.0001), 2.2) * 2.4;
    vec3 floorAmb = srgbToLinear(fogColor) * 0.15 + vec3(0.025) + vec3(0.38) * nightVision;

    vec3 color = albedo * (aSky * 0.58 * skyLight + lCol * diff * skyLight + torchCol + floorAmb);

    float fogF = smoothstep(far * 0.48, far * 0.98, dist);
    vec3 viewDir = safeNormalize(vWorldPos);
    vec3 fogDir = safeNormalize(vec3(viewDir.x, max(viewDir.y, 0.02), viewDir.z));
    color = mix(color, computeSkyBase(fogDir, sunDir, rainStrength), fogF);

    gl_FragColor = vec4(encodeHDR(color), tex.a);
}
