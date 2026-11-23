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

    float cloudsOn = 0.0;
#ifdef REALISTIC_CLOUDS
    cloudsOn = 1.0;
#endif
    float auroraOn = 0.0;
#ifdef AURORA
    auroraOn = 1.0;
#endif

    vec3 col = computeSkyFull(worldDir, sunDir, frameTimeCounter, rainStrength, cloudsOn, auroraOn);

    float nightVis = (1.0 - smoothstep(-0.14, 0.05, sunDir.y)) * (1.0 - rainStrength);
    if (nightVis > 0.01 && worldDir.y > 0.02) {
        vec3 grid = floor(worldDir * 230.0);
        float rnd = hash31(grid);
        if (rnd > 0.992) {
            float twinkle = 0.55 + 0.45 * sin(frameTimeCounter * 2.8 + rnd * 700.0);
            float hFade = smoothstep(0.02, 0.25, worldDir.y);
            vec3 starTint = mix(vec3(0.75, 0.88, 1.0), vec3(1.0, 0.86, 0.72), fract(rnd * 97.3));
            col += starTint * twinkle * hFade * nightVis * 2.2;
        }
    }

    gl_FragColor = vec4(encodeHDR(col), 1.0);
}
