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
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

varying vec2 vTexcoord;

void main() {
    vec3 color = decodeHDR(texture2D(colortex0, vTexcoord).rgb);
    float depth = texture2D(depthtex0, vTexcoord).r;

    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);
    vec3 zen, hor, lCol, aSky;
    getAtmosphere(sunDir.y, rainStrength, zen, hor, lCol, aSky);

    float ign = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

#if defined(VOLUMETRIC_LIGHT) && defined(SHADOWS)
    if (isEyeInWater == 0 && rainStrength < 0.92) {
        vec3 ndcPos = vec3(vTexcoord, depth) * 2.0 - 1.0;
        vec4 viewPosH = gbufferProjectionInverse * vec4(ndcPos, 1.0);
        vec3 viewPos = viewPosH.xyz / max(abs(viewPosH.w), 0.0001);

        vec3 worldStart = (gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        vec3 worldEnd = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 rayVec = worldEnd - worldStart;
        float rayLen = length(rayVec);
        vec3 rayDir = rayVec / max(rayLen, 0.0001);
        float marchDist = min(rayLen, 66.0);

        float cosTheta = dot(rayDir, lightDir);
        float g = 0.66;
        float phase = (1.0 - g * g) / max(pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5), 0.05);
        phase = clamp(phase * 0.24 + 0.14, 0.10, 2.4);

        float vlSum = 0.0;
        for (int i = 0; i < VL_STEPS; i++) {
            float t = (float(i) + ign) / float(VL_STEPS);
            float dStep = marchDist * mix(t, t * t, 0.35);
            vec3 sp = worldStart + rayDir * dStep;
            vec4 shClip = shadowProjection * (shadowModelView * vec4(sp, 1.0));
            vec3 shPos = shClip.xyz / max(abs(shClip.w), 0.0001);

            float lit = 1.0;
            if (abs(shPos.x) < 0.99 && abs(shPos.y) < 0.99) {
                vec2 shUV = distortShadow(shPos.xy) * 0.5 + 0.5;
                float shDepth = (shPos.z * 0.5) * 0.5 + 0.5;
                lit = step(shDepth - 0.001, texture2D(shadowtex0, shUV).r);
            }
            float hDens = exp(-max((sp.y + cameraPosition.y) - 62.0, 0.0) * 0.014);
            vlSum += lit * (0.45 + 0.55 * hDens);
        }
        vlSum /= float(VL_STEPS);

        float sunsetBoost = 1.0 + 1.15 * smoothstep(-0.08, 0.05, sunDir.y) * (1.0 - smoothstep(0.05, 0.35, sunDir.y));
        float distF = clamp(marchDist / 48.0, 0.0, 1.0);
        float eyeSky = clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0);
        float shaftStr = (0.45 + 0.55 * eyeSky) * (1.0 - rainStrength * 0.8) * sunsetBoost;
        color += lCol * vlSum * phase * distF * shaftStr * 0.36;
    }
#endif

#if defined(GODRAYS) || defined(LENS_FLARE)
    float sunVis = smoothstep(-0.06, 0.12, sunDir.y) * (1.0 - rainStrength * 0.92);
    if (sunVis > 0.01 && sunPosition.z < -0.5) {
        vec4 sunClip = gbufferProjection * vec4(sunPosition, 1.0);
        if (sunClip.w > 0.001) {
            vec2 sunUV = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
            float aspect = viewWidth / max(viewHeight, 1.0);

#ifdef GODRAYS
            float screenFade = 1.0 - smoothstep(0.15, 1.35, length((sunUV - vec2(0.5)) * vec2(aspect, 1.0)));
            if (screenFade > 0.01) {
                vec2 delta = (sunUV - vTexcoord) * (0.90 / 14.0);
                vec2 rayUV = vTexcoord + delta * ign;
                float rays = 0.0;
                float decay = 1.0;
                for (int j = 0; j < 14; j++) {
                    rayUV += delta;
                    if (rayUV.x > 0.0 && rayUV.x < 1.0 && rayUV.y > 0.0 && rayUV.y < 1.0) {
                        float d = texture2D(depthtex0, rayUV).r;
                        rays += smoothstep(0.9985, 0.9999, d) * decay;
                    }
                    decay *= 0.88;
                }
                vec3 rayCol = mix(vec3(1.85, 0.62, 0.16), vec3(1.45, 1.25, 0.88), smoothstep(0.0, 0.34, sunDir.y));
                color += rayCol * (rays * 0.095) * sunVis * screenFade;
            }
#endif

#ifdef LENS_FLARE
            if (sunUV.x > 0.0 && sunUV.x < 1.0 && sunUV.y > 0.0 && sunUV.y < 1.0 && isEyeInWater == 0) {
                float sunUnoccluded = smoothstep(0.9985, 0.9999, texture2D(depthtex0, sunUV).r);
                if (sunUnoccluded > 0.01) {
                    vec2 uvA = (vTexcoord - vec2(0.5)) * vec2(aspect, 1.0);
                    vec2 sunA = (sunUV - vec2(0.5)) * vec2(aspect, 1.0);
                    vec2 diff = uvA - sunA;

                    float streak = exp(-abs(diff.y) * 58.0) * exp(-abs(diff.x) * 3.8);
                    vec3 flare = vec3(1.4, 1.05, 0.65) * streak * 0.55;

                    float g1 = max(0.0, 1.0 - length(uvA + sunA * 0.45) * 9.5);
                    float g2 = max(0.0, 1.0 - length(uvA + sunA * 0.85) * 14.0);
                    float g3 = max(0.0, 1.0 - length(uvA - sunA * 0.35) * 12.0);
                    float ring = smoothstep(0.18, 0.21, length(uvA + sunA * 0.65)) * (1.0 - smoothstep(0.21, 0.25, length(uvA + sunA * 0.65)));

                    flare += vec3(0.45, 0.85, 1.2) * (g1 * g1) * 0.22;
                    flare += vec3(1.3, 0.68, 0.28) * (g2 * g2) * 0.28;
                    flare += vec3(0.95, 1.1, 0.55) * (g3 * g3) * 0.16;
                    flare += vec3(0.85, 0.72, 1.15) * ring * 0.18;

                    color += flare * sunVis * sunUnoccluded;
                }
            }
#endif
        }
    }
#endif

    gl_FragColor = vec4(encodeHDR(color), 1.0);
}
