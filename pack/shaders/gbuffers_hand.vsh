#version 120
#include "/lib/common.glsl"

uniform mat4 gbufferModelViewInverse;
varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
    vec3 vn = safeNormalize(gl_NormalMatrix * gl_Normal);
    vWorldNormal = safeNormalize(mat3(gbufferModelViewInverse) * vn);
    gl_Position = ftransform();
}
