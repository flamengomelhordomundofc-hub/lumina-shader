#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

attribute vec4 mc_Entity;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

varying vec2 vTexcoord;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#ifndef SHADOWS
    gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
    return;
#endif
    int blockId = int(mc_Entity.x + 0.5);
    if (blockId == 10001) {
        gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
        return;
    }
    vec4 worldPos = shadowModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
#ifdef WAVING_FOLIAGE
    if (blockId == 10002 || blockId == 10003) {
        float str = (blockId == 10002) ? 0.65 : 1.0;
        worldPos.xyz += getWaveOffset(worldPos.xyz + cameraPosition, frameTimeCounter, rainStrength, str);
    }
#endif
    gl_Position = gl_ProjectionMatrix * (shadowModelView * worldPos);
    gl_Position.xy = distortShadow(gl_Position.xy);
    gl_Position.z *= 0.5;
}
