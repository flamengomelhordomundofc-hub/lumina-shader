#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D colortex0;
varying vec2 vTexcoord;
void main() {
    gl_FragColor = vec4(texture2D(colortex0, vTexcoord).rgb, 0.0);
}
