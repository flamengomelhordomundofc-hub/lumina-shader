#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D colortex0;
varying vec2 vTexcoord;
void main() {
    gl_FragColor = texture2D(colortex0, vTexcoord);
}
