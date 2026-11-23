#version 120
uniform sampler2D colortex0;
varying vec2 vTexcoord;
void main() {
    vec3 c = texture2D(colortex0, vTexcoord).rgb;
    vec2 p = vTexcoord - vec2(0.5);
    c *= clamp(1.0 - dot(p, p) * 0.35, 0.78, 1.0);
    gl_FragColor = vec4(c, 1.0);
}
