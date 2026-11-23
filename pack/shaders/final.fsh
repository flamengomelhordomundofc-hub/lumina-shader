#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
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

    vec4 center = texture2D(colortex0, uv);
    vec3 color = center.rgb;
    float smoothShaft = center.a * 2.0;
    vec3 bloom = vec3(0.0);

    vec2 px = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec2 r1 = px * 2.8;
    vec2 r2 = px * 7.5;

    vec4 s1 = texture2D(colortex0, clamp(uv + vec2( r1.x,  r1.y), 0.0, 1.0));
    vec4 s2 = texture2D(colortex0, clamp(uv + vec2(-r1.x,  r1.y), 0.0, 1.0));
    vec4 s3 = texture2D(colortex0, clamp(uv + vec2( r1.x, -r1.y), 0.0, 1.0));
    vec4 s4 = texture2D(colortex0, clamp(uv + vec2(-r1.x, -r1.y), 0.0, 1.0));
    vec4 s5 = texture2D(colortex0, clamp(uv + vec2( r2.x,  0.0 ), 0.0, 1.0));
    vec4 s6 = texture2D(colortex0, clamp(uv + vec2(-r2.x,  0.0 ), 0.0, 1.0));
    vec4 s7 = texture2D(colortex0, clamp(uv + vec2( 0.0,   r2.y), 0.0, 1.0));
    vec4 s8 = texture2D(colortex0, clamp(uv + vec2( 0.0,  -r2.y), 0.0, 1.0));

    smoothShaft = (smoothShaft + s1.a + s2.a + s3.a + s4.a + s5.a + s6.a + s7.a + s8.a) / 10.0;

#ifdef BLOOM
    bloom += max(s1.rgb - 0.80, 0.0) + max(s2.rgb - 0.80, 0.0) + max(s3.rgb - 0.80, 0.0) + max(s4.rgb - 0.80, 0.0);
    bloom += max(s5.rgb - 0.80, 0.0) + max(s6.rgb - 0.80, 0.0) + max(s7.rgb - 0.80, 0.0) + max(s8.rgb - 0.80, 0.0);
    color += bloom * 0.18 * (1.0 - color * 0.55);
#endif

    if (smoothShaft > 0.002 && isEyeInWater == 0) {
        vec3 sunDir = safeNormalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
        vec3 shaftCol = mix(vec3(1.0, 0.54, 0.18), vec3(1.0, 0.90, 0.68), smoothstep(0.0, 0.35, sunDir.y));
        color += shaftCol * smoothShaft * 0.65 * (1.0 - color * 0.72);
    }

    if (isEyeInWater == 1) {
        float depth = linearDepth(texture2D(depthtex0, uv).r);
        float wFog = clamp(1.0 - exp(-depth * 0.045), 0.0, 0.84);
        color = mix(color, vec3(0.05, 0.30, 0.42), wFog);
    }

#ifdef VIBRANCE
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float maxC = max(color.r, max(color.g, color.b));
    float minC = min(color.r, min(color.g, color.b));
    float sat = maxC - minC;
    color = mix(vec3(luma), color, 1.0 + (1.0 - sat) * 0.24);
    color = clamp((color - 0.5) * 1.05 + 0.5, 0.0, 1.0);
#endif

    vec2 vp = vTexcoord - vec2(0.5);
    float vig = 1.0 - dot(vp, vp) * 0.28;
    color *= clamp(vig, 0.82, 1.0);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
