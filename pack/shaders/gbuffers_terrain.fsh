#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* DRAWBUFFERS:0 */
uniform sampler2D texture;
uniform sampler2D shadowtex0;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int isEyeInWater;
uniform float far;
uniform float nightVision;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

varying vec2 vTexcoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vWorldNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;
varying vec3 vShadowClip;
varying float vBlockType;

#ifdef SHADOWS
float getShadow(vec3 sClip, float NdotL) {
    float edgeDist = max(abs(sClip.x), abs(sClip.y));
    if (edgeDist >= 0.995) return 1.0;
    vec2 uv = distortShadow(sClip.xy) * 0.5 + 0.5;
    float depth = (sClip.z * 0.5) * 0.5 + 0.5;
    if (depth <= 0.001 || depth >= 0.999) return 1.0;

    float bias = 0.0008 + 0.0016 * (1.0 - max(NdotL, 0.0));
    float off = 1.15 / float(shadowMapResolution);
    float lit = 0.0;
    lit += step(depth - bias, texture2D(shadowtex0, uv + vec2( off,  off)).r);
    lit += step(depth - bias, texture2D(shadowtex0, uv + vec2(-off,  off)).r);
    lit += step(depth - bias, texture2D(shadowtex0, uv + vec2( off, -off)).r);
    lit += step(depth - bias, texture2D(shadowtex0, uv + vec2(-off, -off)).r);
    lit *= 0.25;

    return mix(lit, 1.0, smoothstep(0.75, 0.99, edgeDist));
}
#endif

void main() {
    vec4 tex = texture2D(texture, vTexcoord) * vColor;
    if (tex.a < 0.1) discard;

    vec3 albedo = toLinear(tex.rgb);
    vec3 N = safeNormalize(vWorldNormal);
    vec3 viewDir = safeNormalize(vWorldPos);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 skyTop, skyHor, directCol, ambientCol;
    getLightingPalette(sunDir.y, rainStrength, skyTop, skyHor, directCol, ambientCol);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float dist = length(vViewPos);

    float heldVal = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    torchLight = max(torchLight, max(0.0, heldVal - dist / 14.0));

    float isFoliage = float(vBlockType > 0.5 && vBlockType < 1.5);
    float isEmissive = float(vBlockType > 1.5 && vBlockType < 2.5);
    float isOre = float(vBlockType > 2.5);

    float NdotL = dot(N, lightDir);
    float diffuse = max(NdotL, 0.0);
    if (isFoliage > 0.5) {
        diffuse = max(diffuse, 0.46);
    }

    float shadow = 1.0;
#ifdef SHADOWS
    if (skyLight > 0.05 && (NdotL > 0.0 || isFoliage > 0.5)) {
        shadow = getShadow(vShadowClip, NdotL);
    }
#endif
    shadow *= smoothstep(0.04, 0.35, skyLight);

    float hemi = 0.65 + 0.35 * (N.y * 0.5 + 0.5);
    vec3 skyAmb = ambientCol * hemi * (skyLight * skyLight);
    vec3 caveAmb = vec3(0.022, 0.024, 0.028) + vec3(0.35) * nightVision;

    float torchCurve = pow(max(torchLight, 0.0001), 2.2) * 1.95;
    vec3 torchCol = vec3(1.0, 0.55, 0.20) * torchCurve;

    vec3 direct = directCol * diffuse * shadow;
    if (isFoliage > 0.5) {
        float sss = pow(max(dot(viewDir, lightDir), 0.0001), 4.0);
        direct += directCol * sss * 0.45 * shadow;
    }

    if (isEyeInWater == 1 && skyLight > 0.25 && diffuse > 0.0) {
        vec3 absP = vWorldPos + cameraPosition;
        float c1 = sin(absP.x * 1.8 + frameTimeCounter * 2.2) * cos(absP.z * 1.8 - frameTimeCounter * 1.6);
        float caustic = pow(max(c1 * 0.5 + 0.5, 0.0001), 3.0);
        direct += vec3(0.18, 0.58, 0.68) * caustic * 0.45 * shadow * skyLight;
    }

    vec3 color = albedo * (skyAmb + caveAmb + direct + torchCol);

    if (isFoliage < 0.5 && shadow > 0.1 && skyLight > 0.4) {
        vec3 H = safeNormalize(lightDir - viewDir);
        float spec = pow(max(dot(N, H), 0.0001), 32.0) * 0.14;
        color += directCol * spec * shadow;
    }

    if (isEmissive > 0.5) {
        color += albedo * 2.4 + vec3(0.18, 0.10, 0.02);
    }

    if (isOre > 0.5) {
        float maxC = max(tex.r, max(tex.g, tex.b));
        float minC = min(tex.r, min(tex.g, tex.b));
        float sat = (maxC - minC) / max(maxC, 0.001);
        color += albedo * smoothstep(0.25, 0.55, sat) * 1.8;
    }

    if (rainStrength > 0.08 && skyLight > 0.85 && N.y > 0.7 && isFoliage < 0.5) {
        float wet = rainStrength * smoothstep(0.85, 0.98, skyLight);
        color *= (1.0 - wet * 0.22);
        float fres = pow(1.0 - max(dot(-viewDir, N), 0.0), 3.0);
        color = mix(color, skyHor * 0.65, wet * fres * 0.35);
    }

    float fogF = smoothstep(far * 0.52, far * 0.98, dist);
    fogF = clamp(fogF + smoothstep(26.0, far * 1.5, dist) * (0.08 + 0.18 * rainStrength), 0.0, 1.0);
    vec3 fogDir = safeNormalize(vec3(viewDir.x, max(viewDir.y, 0.02), viewDir.z));
    vec3 fogCol = computeSky(fogDir, sunDir, frameTimeCounter, rainStrength, 0.0);
    color = mix(color, fogCol, fogF);

    color = toSRGB(softToneMap(color));
    gl_FragColor = vec4(color, tex.a);
}
