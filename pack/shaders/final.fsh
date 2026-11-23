#version 120
#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform float near;
uniform float far;

varying vec2 vTexcoord;

vec3 sampleBloom(vec2 uv) {
    vec3 c = decodeHDR(texture2D(colortex0, clamp(uv, 0.001, 0.999)).rgb);
    return max(c - vec3(1.05), vec3(0.0));
}

void main() {
    vec2 uv = vTexcoord;

    if (isEyeInWater == 1) {
        uv.x += sin(uv.y * 19.0 + frameTimeCounter * 3.2) * 0.0032;
        uv.y += cos(uv.x * 17.0 + frameTimeCounter * 2.6) * 0.0032;
        uv = clamp(uv, 0.002, 0.998);
    }

    vec3 color = decodeHDR(texture2D(colortex0, uv).rgb);
    vec2 px = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));

#ifdef BLOOM
    vec3 b1 = vec3(0.0);
    vec2 r1 = px * 4.0;
    b1 += sampleBloom(uv + vec2( r1.x,  r1.y));
    b1 += sampleBloom(uv + vec2(-r1.x,  r1.y));
    b1 += sampleBloom(uv + vec2( r1.x, -r1.y));
    b1 += sampleBloom(uv + vec2(-r1.x, -r1.y));

    vec3 b2 = vec3(0.0);
    vec2 r2 = px * 11.0;
    b2 += sampleBloom(uv + vec2( r2.x,  0.0 ));
    b2 += sampleBloom(uv + vec2(-r2.x,  0.0 ));
    b2 += sampleBloom(uv + vec2( 0.0,   r2.y));
    b2 += sampleBloom(uv + vec2( 0.0,  -r2.y));

    vec3 b3 = vec3(0.0);
    vec2 r3 = px * 24.0;
    b3 += sampleBloom(uv + vec2( r3.x,  r3.y));
    b3 += sampleBloom(uv + vec2(-r3.x,  r3.y));
    b3 += sampleBloom(uv + vec2( r3.x, -r3.y));
    b3 += sampleBloom(uv + vec2(-r3.x, -r3.y));

    vec3 b4 = vec3(0.0);
    vec2 r4 = px * 42.0;
    b4 += sampleBloom(uv + vec2( r4.x,  0.0 ));
    b4 += sampleBloom(uv + vec2(-r4.x,  0.0 ));
    b4 += sampleBloom(uv + vec2( 0.0,   r4.y));
    b4 += sampleBloom(uv + vec2( 0.0,  -r4.y));

    vec3 bloom = (b1 * 0.36 + b2 * 0.28 + b3 * 0.22 + b4 * 0.14) * 0.11;
    color += bloom;
#endif

    if (isEyeInWater == 1) {
        float depth = linearizeDepth(texture2D(depthtex0, uv).r, near, far);
        float waterFog = clamp(1.0 - exp(-depth * 0.052), 0.0, 0.90);
        color = mix(color, vec3(0.02, 0.22, 0.36), waterFog);
    }

    color = acesToneMap(color * 1.06);
    color = linearToSRGB(color);

#ifdef VIBRANCE
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float maxC = max(color.r, max(color.g, color.b));
    float minC = min(color.r, min(color.g, color.b));
    float sat = maxC - minC;
    color = mix(vec3(luma), color, 1.0 + (1.0 - sat) * 0.30);
    color = clamp((color - 0.5) * 1.05 + 0.5, 0.0, 1.0);
#endif

    vec2 vp = vTexcoord - vec2(0.5);
    float vig = 1.0 - dot(vp, vp) * 0.38;
    color *= clamp(vig, 0.76, 1.0);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
