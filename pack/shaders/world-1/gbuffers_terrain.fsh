#version 120
#include "/lib/common.glsl"
/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform vec3 fogColor;
uniform float far;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vViewPos;

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    if (tex.a < 0.1) discard;
    vec3 albedo = srgbToLinear(tex.rgb);
    float dist = length(vViewPos);
    float torch = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float held = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    torch = max(torch, max(0.0, held - dist / 15.0));

    float shade = 0.68 + 0.32 * (vNormal.y * 0.5 + 0.5);
    vec3 amb = mix(vec3(0.28, 0.08, 0.04), srgbToLinear(fogColor) * 0.9, 0.55) * shade;
    vec3 light = amb + vec3(1.5, 0.58, 0.18) * pow(max(torch, 0.0001), 2.1) * 2.6;
    vec3 col = albedo * light;
    float fogF = smoothstep(far * 0.22, far * 0.90, dist);
    col = mix(col, srgbToLinear(fogColor) * 0.72, fogF);
    gl_FragColor = vec4(encodeHDR(col), tex.a);
}
