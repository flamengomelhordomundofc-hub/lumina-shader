#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

varying vec2 vTexcoord;

void main() {
    vec3 color = texture2D(colortex0, vTexcoord).rgb;
    float shaft = 0.0;

    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    float sunVis = smoothstep(-0.02, 0.14, sunDir.y) * (1.0 - rainStrength * 0.88);

    if (sunVis > 0.01 && isEyeInWater == 0) {
        float ign = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

#if defined(VOLUMETRIC_LIGHT) && defined(SHADOWS)
        float depth = texture2D(depthtex0, vTexcoord).r;
        vec3 ndcPos = vec3(vTexcoord, depth) * 2.0 - 1.0;
        vec4 viewPosH = gbufferProjectionInverse * vec4(ndcPos, 1.0);
        vec3 viewPos = viewPosH.xyz / max(abs(viewPosH.w), 0.0001);

        vec3 worldStart = (gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        vec3 worldEnd = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 rayVec = worldEnd - worldStart;
        float rayLen = length(rayVec);
        vec3 rayDir = rayVec / max(rayLen, 0.0001);
        float marchDist = min(rayLen, 58.0);

        float cosT = dot(rayDir, sunDir);
        float phase = 0.22 + 0.78 * pow(max(cosT * 0.5 + 0.5, 0.0001), 3.0);

        float vl = 0.0;
        for (int i = 0; i < 6; i++) {
            float t = (float(i) + ign) / 6.0;
            vec3 sp = worldStart + rayDir * (marchDist * t);
            vec4 shClip = shadowProjection * (shadowModelView * vec4(sp, 1.0));
            vec3 shPos = shClip.xyz / max(abs(shClip.w), 0.0001);
            if (abs(shPos.x) < 0.98 && abs(shPos.y) < 0.98) {
                vec2 shUV = distortShadow(shPos.xy) * 0.5 + 0.5;
                float shDepth = (shPos.z * 0.5) * 0.5 + 0.5;
                vl += step(shDepth - 0.001, texture2D(shadowtex0, shUV).r);
            }
        }
        vl /= 6.0;
        float eyeSky = clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0);
        float distF = clamp(marchDist / 45.0, 0.0, 1.0);
        shaft += vl * phase * distF * (0.35 + 0.65 * eyeSky) * 0.55;
#endif

#ifdef GODRAYS
        if (sunPosition.z < -0.2) {
            vec4 sunClip = gbufferProjection * vec4(sunPosition, 1.0);
            if (sunClip.w > 0.001) {
                vec2 sunUV = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
                float aspect = viewWidth / max(viewHeight, 1.0);
                float sunDistScreen = length((sunUV - vec2(0.5)) * vec2(aspect, 1.0));
                float screenFade = 1.0 - smoothstep(0.35, 1.45, sunDistScreen);

                if (screenFade > 0.01) {
                    vec2 delta = (sunUV - vTexcoord) * (0.85 / 10.0);
                    vec2 rayUV = vTexcoord + delta * ign;
                    float rays = 0.0;
                    float decay = 1.0;

                    for (int j = 0; j < 10; j++) {
                        rayUV += delta;
                        if (rayUV.x > 0.0 && rayUV.x < 1.0 && rayUV.y > 0.0 && rayUV.y < 1.0) {
                            float d = texture2D(depthtex0, rayUV).r;
                            float isSky = step(0.999, d);
                            float distToSun = length((rayUV - sunUV) * vec2(aspect, 1.0));
                            float radialMask = exp(-distToSun * 1.9);
                            rays += isSky * radialMask * decay;
                        }
                        decay *= 0.88;
                    }
                    shaft += (rays / 10.0) * 1.45 * screenFade;
                }
            }
        }
#endif

        shaft *= sunVis;
    }

    gl_FragColor = vec4(color, clamp(shaft, 0.0, 1.0));
}
