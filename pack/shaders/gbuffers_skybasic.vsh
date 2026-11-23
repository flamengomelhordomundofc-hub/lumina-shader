#version 120
varying vec3 vViewPos;

void main() {
    vec4 vp = gl_ModelViewMatrix * gl_Vertex;
    vViewPos = vp.xyz;
    gl_Position = gl_ProjectionMatrix * vp;
}
