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

    float bias = 0.0007 + 0.0014 * (1.0 - max(NdotL, 0.0));
    float off = 1.25 / float(shadowMapResolution);
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

    vec3 albedo = srgbToLinear(tex.rgb);
    vec3 N = safeNormalize(vWorldNormal);
    vec3 viewWorldDir = safeNormalize(vWorldPos);
    vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    vec3 lightDir = safeNormalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);

    vec3 zen, hor, lCol, aSky;
    getAtmosphere(sunDir.y, rainStrength, zen, hor, lCol, aSky);

    float torchLight = clamp((vLightmap.x - 0.03125) / 0.9375, 0.0, 1.0);
    float skyLight = clamp((vLightmap.y - 0.03125) / 0.9375, 0.0, 1.0);
    float dist = length(vViewPos);

    float heldVal = max(float(heldBlockLightValue), float(heldBlockLightValue2)) / 15.0;
    torchLight = max(torchLight, max(0.0, heldVal - dist / 15.0));

    float isFoliage = float(vBlockType > 0.5 && vBlockType < 1.5);
    float isEmissive = float(vBlockType > 1.5 && vBlockType < 2.5);
    float isOre = float(vBlockType > 2.5);

    vec3 bumpN = N;
#ifdef AUTO_BUMP
    if (isFoliage < 0.5 && dist < 38.0) {
        float eps = 0.00032;
        float hC = dot(tex.rgb, vec3(0.3, 0.59, 0.11));
        float hX = dot(texture2D(texture, vTexcoord + vec2(eps, 0.0)).rgb * vColor.rgb, vec3(0.3, 0.59, 0.11));
        float hY = dot(texture2D(texture, vTexcoord + vec2(0.0, eps)).rgb * vColor.rgb, vec3(0.3, 0.59, 0.11));
        float dx = clamp((hC - hX) * 2.8, -0.35, 0.35);
        float dy = clamp((hC - hY) * 2.8, -0.35, 0.35);
        vec3 T = (abs(N.y) > 0.5) ? vec3(1.0, 0.0, 0.0) : safeNormalize(cross(vec3(0.0, 1.0, 0.0), N));
        vec3 B = safeNormalize(cross(N, T));
        bumpN = safeNormalize(N + (T * dx + B * dy) * (1.0 - smoothstep(22.0, 38.0, dist)));
    }
#endif

    float NdotL = dot(bumpN, lightDir);
    float diffuse = max(NdotL, 0.0);
    if (isFoliage > 0.5) {
        diffuse = max(dot(N, lightDir), 0.45);
    }

    float shadow = 1.0;
#ifdef SHADOWS
    if (skyLight > 0.05 && (diffuse > 0.0 || isFoliage > 0.5)) {
        shadow = getShadow(vShadowClip, dot(N, lightDir));
    }
#endif
    shadow *= smoothstep(0.04, 0.36, skyLight);

    float hemi = bumpN.y * 0.5 + 0.5;
    vec3 skyAmbient = mix(aSky * 0.22, aSky * 0.62, hemi) * (skyLight * skyLight);
    vec3 caveAmbient = vec3(0.015, 0.020, 0.032) + vec3(0.38) * nightVision;

    float torchCurve = pow(max(torchLight, 0.0001), 2.3) * 2.5;
    vec3 torchColor = vec3(1.0, 0.52, 0.16) * torchCurve;

    vec3 direct = lCol * diffuse * shadow;

    if (isFoliage > 0.5) {
        float backLit = pow(max(dot(viewWorldDir, lightDir), 0.0001), 3.5);
        direct += lCol * backLit * 0.68 * shadow;
    }

    vec3 absP = vWorldPos + cameraPosition;
    if (isEyeInWater == 1 && skyLight > 0.25 && diffuse > 0.0) {
        float c1 = sin(absP.x * 1.9 + frameTimeCounter * 2.4) * cos(absP.z * 1.9 - frameTimeCounter * 1.8);
        float c2 = sin((absP.x + absP.z) * 1.5 - frameTimeCounter * 2.7);
        float caustic = pow(max(c1 * 0.5 + c2 * 0.5 + 0.5, 0.0001), 3.0);
        direct += vec3(0.28, 0.85, 0.95) * caustic * 0.65 * shadow * skyLight;
    }

    vec3 color = albedo * (skyAmbient + caveAmbient + direct + torchColor);

    if (isFoliage < 0.5 && shadow > 0.05 && skyLight > 0.3) {
        vec3 H = safeNormalize(lightDir - viewWorldDir);
        float spec = pow(max(dot(bumpN, H), 0.0001), 28.0) * 0.24;
        color += lCol * spec * shadow * skyLight;
    }

    if (isEmissive > 0.5) {
        color += albedo * 4.8 + vec3(0.35, 0.18, 0.04);
    }

    if (isOre > 0.5) {
        float maxC = max(tex.r, max(tex.g, tex.b));
        float minC = min(tex.r, min(tex.g, tex.b));
        float sat = (maxC - minC) / max(maxC, 0.001);
        float glowMask = smoothstep(0.24, 0.55, sat);
        color += albedo * glowMask * 3.2;
    }

    if (rainStrength > 0.05 && skyLight > 0.80 && N.y > 0.65 && isFoliage < 0.5) {
        vec2 wp = absP.xz * 0.32;
        float puddle = smoothstep(0.05, 0.62, sin(wp.x) * cos(wp.y) + 0.5 * sin(wp.x * 2.3 + wp.y * 1.7));
        float wet = puddle * rainStrength * smoothstep(0.80, 0.98, skyLight);
        color *= (1.0 - wet * 0.38);
        vec3 R = reflect(viewWorldDir, mix(bumpN, N, 0.7));
        vec3 refl = computeSkyBase(R, sunDir, rainStrength);
        float fres = pow(1.0 - max(dot(-viewWorldDir, N), 0.0), 3.0);
        color = mix(color, refl * 1.1, wet * (0.22 + 0.62 * fres));
    }

    float fogF = smoothstep(far * 0.48, far * 0.98, dist);
    float valleyHaze = smoothstep(18.0, far * 1.35, dist) * (0.12 + 0.24 * rainStrength);
    fogF = clamp(fogF + valleyHaze, 0.0, 1.0);
    vec3 fogDir = safeNormalize(vec3(viewWorldDir.x, max(viewWorldDir.y, 0.02), viewWorldDir.z));
    vec3 fogCol = computeSkyBase(fogDir, sunDir, rainStrength);
    color = mix(color, fogCol, fogF);

    gl_FragColor = vec4(encodeHDR(color), tex.a);
}
