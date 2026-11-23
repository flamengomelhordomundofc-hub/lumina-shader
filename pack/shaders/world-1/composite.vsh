#version 120
varying vec2 vTexcoord;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gl_Position = ftransform();
}
