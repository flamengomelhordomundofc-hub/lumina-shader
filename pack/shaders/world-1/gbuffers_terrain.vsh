#version 120
#include "/lib/common.glsl"
uniform mat4 gbufferModelViewInverse;
varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vViewPos;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
    vNormal = safeNormalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
    vec4 vp = gl_ModelViewMatrix * gl_Vertex;
    vViewPos = vp.xyz;
    gl_Position = gl_ProjectionMatrix * vp;
}
