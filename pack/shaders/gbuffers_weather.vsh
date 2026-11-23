#version 120
uniform mat4 gbufferModelViewInverse;
varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vViewPos;
varying vec3 vWorldPos;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
    vec4 vp = gl_ModelViewMatrix * gl_Vertex;
    vViewPos = vp.xyz;
    vWorldPos = (gbufferModelViewInverse * vp).xyz;
    gl_Position = gl_ProjectionMatrix * vp;
}
