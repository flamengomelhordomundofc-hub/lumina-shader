#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform float far;
uniform vec3 fogColor;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vViewPos;
varying vec3 vWorldPos;

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    if (tex.a < 0.05) discard;

    vec3 albedo = srgbToLinear(tex.rgb);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 zen, hor, lCol, aSky;
    getAtmosphere(sunDir.y, rainStrength, zen, hor, lCol, aSky);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    vec3 torchCol = vec3(1.0, 0.54, 0.18) * pow(max(torchLight, 0.0001), 2.0) * 2.4;

    vec3 color = albedo * ((aSky * 0.65 + lCol * 0.45) * skyLight + torchCol + srgbToLinear(fogColor) * 0.14 + vec3(0.05));
    float fogF = smoothstep(far * 0.48, far * 0.98, length(vViewPos));
    vec3 vDir = safeNormalize(vWorldPos);
    vec3 fogDir = safeNormalize(vec3(vDir.x, max(vDir.y, 0.02), vDir.z));
    color = mix(color, computeSkyBase(fogDir, sunDir, rainStrength), fogF);

    gl_FragColor = vec4(encodeHDR(color), tex.a);
}
