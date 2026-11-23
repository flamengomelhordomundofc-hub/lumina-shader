#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int isEyeInWater;
uniform float near;
uniform float far;

varying vec2 vTexcoord;

float linearDepth(float d) {
    return (2.0 * near * far) / max(far + near - (d * 2.0 - 1.0) * (far - near), 0.0001);
}

void main() {
    vec2 uv = vTexcoord;

    if (isEyeInWater == 1) {
        uv.x += sin(uv.y * 16.0 + frameTimeCounter * 2.8) * 0.0025;
        uv.y += cos(uv.x * 14.0 + frameTimeCounter * 2.4) * 0.0025;
        uv = clamp(uv, 0.002, 0.998);
    }

    vec3 color = texture2D(colortex0, uv).rgb;
    vec2 px = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));

#ifdef BLOOM
    vec3 b = vec3(0.0);
    vec2 r1 = px * 3.5;
    vec2 r2 = px * 9.5;
    b += max(texture2D(colortex0, clamp(uv + vec2( r1.x,  r1.y), 0.0, 1.0)).rgb - 0.78, 0.0);
    b += max(texture2D(colortex0, clamp(uv + vec2(-r1.x,  r1.y), 0.0, 1.0)).rgb - 0.78, 0.0);
    b += max(texture2D(colortex0, clamp(uv + vec2( r1.x, -r1.y), 0.0, 1.0)).rgb - 0.78, 0.0);
    b += max(texture2D(colortex0, clamp(uv + vec2(-r1.x, -r1.y), 0.0, 1.0)).rgb - 0.78, 0.0);
    b += max(texture2D(colortex0, clamp(uv + vec2( r2.x,  0.0 ), 0.0, 1.0)).rgb - 0.78, 0.0);
    b += max(texture2D(colortex0, clamp(uv + vec2(-r2.x,  0.0 ), 0.0, 1.0)).rgb - 0.78, 0.0);
    b += max(texture2D(colortex0, clamp(uv + vec2( 0.0,   r2.y), 0.0, 1.0)).rgb - 0.78, 0.0);
    b += max(texture2D(colortex0, clamp(uv + vec2( 0.0,  -r2.y), 0.0, 1.0)).rgb - 0.78, 0.0);
    color += b * 0.14 * (1.0 - color * 0.5);
#endif

#ifdef GODRAYS
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    float sunVis = smoothstep(-0.04, 0.14, sunDir.y) * (1.0 - rainStrength * 0.90);
    if (sunVis > 0.01 && sunPosition.z < -0.5 && isEyeInWater == 0) {
        vec4 sunClip = gbufferProjection * vec4(sunPosition, 1.0);
        if (sunClip.w > 0.001) {
            vec2 sunUV = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
            float aspect = viewWidth / max(viewHeight, 1.0);
            float sunOffCenter = length((sunUV - vec2(0.5)) * vec2(aspect, 1.0));
            float screenFade = 1.0 - smoothstep(0.25, 1.25, sunOffCenter);

            if (screenFade > 0.01) {
                vec2 delta = (sunUV - uv) * (0.88 / 12.0);
                float ign = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
                vec2 rayUV = uv + delta * ign;
                float rays = 0.0;
                float decay = 1.0;

                for (int i = 0; i < 12; i++) {
                    rayUV += delta;
                    if (rayUV.x > 0.0 && rayUV.x < 1.0 && rayUV.y > 0.0 && rayUV.y < 1.0) {
                        float d = texture2D(depthtex0, rayUV).r;
                        float isSky = step(0.999, d);
                        float sunDist = length((rayUV - sunUV) * vec2(aspect, 1.0));
                        float mask = exp(-sunDist * 3.2);
                        rays += isSky * mask * decay;
                    }
                    decay *= 0.89;
                }

                float rayAmt = min(rays * 0.14, 0.62) * sunVis * screenFade;
                vec3 rayCol = mix(vec3(1.0, 0.52, 0.18), vec3(1.0, 0.90, 0.68), smoothstep(0.0, 0.34, sunDir.y));
                color += rayCol * rayAmt * (1.0 - color * 0.65);
            }
        }
    }
#endif

    if (isEyeInWater == 1) {
        float depth = linearDepth(texture2D(depthtex0, uv).r);
        float wFog = clamp(1.0 - exp(-depth * 0.045), 0.0, 0.85);
        color = mix(color, vec3(0.05, 0.28, 0.38), wFog);
    }

#ifdef VIBRANCE
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float maxC = max(color.r, max(color.g, color.b));
    float minC = min(color.r, min(color.g, color.b));
    float sat = maxC - minC;
    color = mix(vec3(luma), color, 1.0 + (1.0 - sat) * 0.22);
    color = clamp((color - 0.5) * 1.04 + 0.5, 0.0, 1.0);
#endif

    vec2 vp = vTexcoord - vec2(0.5);
    float vig = 1.0 - dot(vp, vp) * 0.30;
    color *= clamp(vig, 0.82, 1.0);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
