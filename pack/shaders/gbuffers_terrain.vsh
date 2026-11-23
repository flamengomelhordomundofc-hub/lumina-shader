#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

attribute vec4 mc_Entity;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;
varying vec3 vShadowClip;
varying float vBlockType;

void main() {
    vTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;

    vec3 viewNormal = safeNormalize(gl_NormalMatrix * gl_Normal);
    vWorldNormal = safeNormalize(mat3(gbufferModelViewInverse) * viewNormal);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec4 worldPos = gbufferModelViewInverse * viewPos;

    int blockId = int(mc_Entity.x + 0.5);
    vBlockType = 0.0;
    if (blockId == 10002 || blockId == 10003) {
        vBlockType = 1.0;
#ifdef WAVING_FOLIAGE
        float str = (blockId == 10002) ? 0.65 : 1.0;
        worldPos.xyz += getWaveOffset(worldPos.xyz + cameraPosition, frameTimeCounter, rainStrength, str);
        viewPos = gbufferModelView * worldPos;
#endif
    } else if (blockId == 10004) {
        vBlockType = 2.0;
    } else if (blockId == 10005) {
        vBlockType = 3.0;
    }

    vViewPos = viewPos.xyz;
    vWorldPos = worldPos.xyz;

#ifdef SHADOWS
    vec4 shWorld = vec4(worldPos.xyz + vWorldNormal * 0.055, 1.0);
    vec4 shClip = shadowProjection * (shadowModelView * shWorld);
    vShadowClip = shClip.xyz / max(abs(shClip.w), 0.0001);
#else
    vShadowClip = vec3(0.0);
#endif

    gl_Position = gl_ProjectionMatrix * viewPos;
}
