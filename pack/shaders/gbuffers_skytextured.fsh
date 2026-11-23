#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform float rainStrength;
varying vec2 vTexcoord;
varying vec4 vColor;

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    tex.rgb *= (0.75 * (1.0 - rainStrength * 0.9));
    gl_FragColor = tex;
}
