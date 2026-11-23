#version 120
varying vec2 vTexcoord;
varying vec4 vColor;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor = gl_Color;
    gl_Position = ftransform();
}
