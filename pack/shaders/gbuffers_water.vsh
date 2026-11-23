#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

attribute vec4 mc_Entity;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;
varying float vIsWater;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;

    vec3 viewNormal = safeNormalize(gl_NormalMatrix * gl_Normal);
    vWorldNormal = safeNormalize(mat3(gbufferModelViewInverse) * viewNormal);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec4 worldPos = gbufferModelViewInverse * viewPos;

    int blockId = int(mc_Entity.x + 0.5);
    vIsWater = (blockId == 10001) ? 1.0 : 0.0;

#ifdef REALISTIC_WATER
    if (vIsWater > 0.5) {
        vec3 absP = worldPos.xyz + cameraPosition;
        float w1 = sin(absP.x * 1.5 + frameTimeCounter * 2.4) * cos(absP.z * 1.3 + frameTimeCounter * 1.9);
        float w2 = sin((absP.x - absP.z) * 1.1 - frameTimeCounter * 2.1);
        worldPos.y += (w1 * 0.045 + w2 * 0.025);
        viewPos = gbufferModelView * worldPos;
    }
#endif

    vViewPos = viewPos.xyz;
    vWorldPos = worldPos.xyz;
    gl_Position = gl_ProjectionMatrix * viewPos;
}
