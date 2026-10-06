#include <metal_stdlib>
using namespace metal;

// Value-noise building blocks for the warp/flow field.
static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float vnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
    return v;
}

/// A warped, grainy three-colour gradient (Grainient preset: warp 1 / freq 5 /
/// speed 2 / amp 50, noiseScale 2, grain 0.1, contrast 1.5, zoom 0.9). The three
/// colours come from the chosen background color; `time` animates the flow.
[[ stitchable ]] half4 grainient(float2 pos, half4 color, float2 size, float time,
                                 half4 c1, half4 c2, half4 c3) {
    float2 uv = pos / size;                     // 0..1
    float2 p = (uv - 0.5) / 0.9;                // centred + zoom 0.9
    float t = time * 0.5;                       // timeSpeed (lively)

    float2 q = p * 2.0;                         // noiseScale
    float2 warp = float2(fbm(q * 5.0 + t * 2.0),
                         fbm(q * 5.0 + 11.3 - t * 2.0));
    warp = (warp - 0.5) * 2.0;
    p += warp * (50.0 / max(size.x, size.y));   // warpAmplitude (px -> uv)

    float swirl = fbm(q + t) * (500.0 / 360.0);
    float g = p.x + fbm(q * 2.0 + t) * 0.6 + sin(swirl) * 0.15 + 0.5;
    g = clamp(g, 0.0, 1.0);

    half3 col = g < 0.5
        ? mix(c1.rgb, c2.rgb, half(smoothstep(-0.05, 0.55, g)))
        : mix(c2.rgb, c3.rgb, half(smoothstep(0.45, 1.05, g)));

    col = (col - 0.5) * 1.5 + 0.5;              // contrast 1.5

    float grain = hash21(uv * size / 2.0);      // grainScale 2, static
    col += half3(half((grain - 0.5) * 0.1));    // grainAmount 0.1

    col = clamp(col, half3(0.0), half3(1.0));
    return half4(col, 1.0);
}
