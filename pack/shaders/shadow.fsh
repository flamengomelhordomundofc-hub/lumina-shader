#version 120
uniform sampler2D texture;
varying vec2 vTexcoord;

void main() {
    if (texture2D(texture, vTexcoord).a < 0.1) discard;
    gl_FragColor = vec4(1.0);
}
