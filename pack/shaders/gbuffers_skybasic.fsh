#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform float frameTimeCounter;

varying vec3 vViewPos;

float hash31(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

void main() {
    vec3 worldDir = safeNormalize((gbufferModelViewInverse * vec4(vViewPos, 0.0)).xyz);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);

    float cloudQ = 0.0;
#ifdef REALISTIC_CLOUDS
    cloudQ = 2.0;
#endif

    vec3 col = computeSky(worldDir, sunDir, frameTimeCounter, rainStrength, cloudQ);

    float nightVis = (1.0 - smoothstep(-0.12, 0.05, sunDir.y)) * (1.0 - rainStrength);
    if (nightVis > 0.01 && worldDir.y > 0.02) {
        vec3 grid = floor(worldDir * 220.0);
        float rnd = hash31(grid);
        if (rnd > 0.992) {
            float twinkle = 0.6 + 0.4 * sin(frameTimeCounter * 2.6 + rnd * 600.0);
            float hFade = smoothstep(0.02, 0.25, worldDir.y);
            col += vec3(0.85, 0.92, 1.0) * twinkle * hFade * nightVis * 1.4;
        }
    }

    col = toSRGB(filmicToneMap(col));
    gl_FragColor = vec4(col, 1.0);
}
