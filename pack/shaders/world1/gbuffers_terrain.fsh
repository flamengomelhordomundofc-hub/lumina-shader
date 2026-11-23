#version 120
#include "/lib/common.glsl"
/* DRAWBUFFERS:0 */
uniform sampler2D texture;
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

    float shade = 0.65 + 0.35 * (vNormal.y * 0.5 + 0.5);
    vec3 amb = vec3(0.22, 0.14, 0.36) * shade;
    vec3 light = amb + vec3(1.1, 0.68, 1.4) * pow(max(torch, 0.0001), 2.1) * 2.2;
    vec3 col = albedo * light;
    float fogF = smoothstep(far * 0.42, far * 0.96, dist);
    col = mix(col, vec3(0.06, 0.03, 0.12), fogF);
    gl_FragColor = vec4(encodeHDR(col), tex.a);
}
